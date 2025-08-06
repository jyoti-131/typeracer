defmodule Typeracer.Stats do
  import Ecto.Query, warn: false
  alias Typeracer.Repo
  alias Typeracer.Accounts.{UserProfile, TypingSession, DailyStat, CharacterMistake}

  def get_or_create_user_profile(user_id) do
    case Repo.get_by(UserProfile, user_id: user_id) do
      nil -> create_user_profile(%{user_id: user_id})
      profile -> {:ok, profile}
    end
  end

  def get_user_profile(profile_id) when is_integer(profile_id) do
    case Repo.get(UserProfile, profile_id) do
      nil -> {:error, :not_found}
      profile -> {:ok, profile}
    end
  end

  def create_user_profile(attrs) do
    %UserProfile{}
    |> UserProfile.changeset(attrs)
    |> Repo.insert()
  end

  def update_user_profile(%UserProfile{} = profile, attrs) do
    # Clean username if it's being updated
    cleaned_attrs = case Map.get(attrs, :username) do
      nil -> attrs
      username when is_binary(username) -> 
        Map.put(attrs, :username, String.trim(username))
      _ -> attrs
    end
    
    profile
    |> UserProfile.changeset(cleaned_attrs)
    |> Repo.update()
  end

  # Add overload to handle profile ID (for your index.ex compatibility)
  def update_user_profile(profile_id, attrs) when is_integer(profile_id) do
    case Repo.get(UserProfile, profile_id) do
      nil -> {:error, :not_found}
      profile -> update_user_profile(profile, attrs)
    end
  end

  # NEW: Dedicated function for updating username - called by ProfileLive.Index
  def update_username(profile_id, username) when is_integer(profile_id) and is_binary(username) do
    cleaned_username = String.trim(username)
    
    # Validate username
    cond do
      String.length(cleaned_username) == 0 ->
        {:error, :empty_username}
      
      String.length(cleaned_username) > 50 ->
        {:error, :username_too_long}
      
      # Check if username already exists for another user (optional uniqueness check)
      username_exists?(cleaned_username, profile_id) ->
        {:error, :username_taken}
      
      true ->
        case Repo.get(UserProfile, profile_id) do
          nil -> 
            {:error, :not_found}
          profile -> 
            profile
            |> UserProfile.changeset(%{username: cleaned_username})
            |> Repo.update()
        end
    end
  end

  def update_username(%UserProfile{} = profile, username) when is_binary(username) do
    cleaned_username = String.trim(username)
    
    # Validate username
    cond do
      String.length(cleaned_username) == 0 ->
        {:error, :empty_username}
      
      String.length(cleaned_username) > 50 ->
        {:error, :username_too_long}
      
      # Check if username already exists for another user (optional uniqueness check)
      username_exists?(cleaned_username, profile.id) ->
        {:error, :username_taken}
      
      true ->
        profile
        |> UserProfile.changeset(%{username: cleaned_username})
        |> Repo.update()
    end
  end

  # Helper function to check if username is already taken (optional - remove if you don't want unique usernames)
  defp username_exists?(username, exclude_profile_id) do
    from(p in UserProfile,
      where: p.username == ^username and p.id != ^exclude_profile_id
    )
    |> Repo.exists?()
  end

  # NEW: Get user profile by username (useful for searching)
  def get_user_profile_by_username(username) when is_binary(username) do
    case Repo.get_by(UserProfile, username: String.trim(username)) do
      nil -> {:error, :not_found}
      profile -> {:ok, profile}
    end
  end

  # This is what your RaceLive.Index is calling
  def create_typing_session(attrs) do
    result = %TypingSession{}
    |> TypingSession.changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, session} ->
        # Update profile stats after creating session
        update_user_profile_stats(session.user_profile_id)
        {:ok, session}
      error -> error
    end
  end

  # Keep the old function for compatibility
  def record_typing_session(user_profile_id, session_data) do
    session_attrs = Map.merge(session_data, %{
      user_profile_id: user_profile_id,
      completed_at: DateTime.utc_now()
    })

    result = %TypingSession{}
    |> TypingSession.changeset(session_attrs)
    |> Repo.insert()

    case result do
      {:ok, session} ->
        update_profile_stats(user_profile_id, session_data)
        update_daily_stats(user_profile_id, session_data)
        {:ok, session}
      error -> error
    end
  end

  # This function recalculates stats from all sessions - called by RaceLive.Index
  def update_user_profile_stats(user_profile_id) do
    profile = Repo.get!(UserProfile, user_profile_id)
    
    # Get all sessions for this profile
    sessions = from(s in TypingSession,
      where: s.user_profile_id == ^user_profile_id,
      select: %{
        wpm: s.wpm,
        accuracy: s.accuracy,
        mistakes_count: s.mistakes_count,
        total_keystrokes: s.total_keystrokes,
        time_taken: s.time_taken
      }
    ) |> Repo.all()

    if length(sessions) > 0 do
      total_tests = length(sessions)
      
      # Calculate averages - ensure we handle nil values
      total_wpm = Enum.reduce(sessions, 0, fn session, acc -> acc + (session.wpm || 0) end)
      average_wpm = if total_tests > 0, do: total_wpm / total_tests, else: 0.0
      
      total_accuracy = Enum.reduce(sessions, 0, fn session, acc -> acc + (session.accuracy || 0) end)
      average_accuracy = if total_tests > 0, do: total_accuracy / total_tests, else: 0.0
      
      # Calculate bests - ensure we handle nil values
      best_wpm = Enum.reduce(sessions, 0, fn session, acc -> max(acc, session.wpm || 0) end)
      best_accuracy = Enum.reduce(sessions, 0.0, fn session, acc -> max(acc, session.accuracy || 0.0) end)
      
      # Calculate totals - ensure we handle nil values
      total_keystrokes = Enum.reduce(sessions, 0, fn session, acc -> acc + (session.total_keystrokes || 0) end)
      total_mistakes = Enum.reduce(sessions, 0, fn session, acc -> acc + (session.mistakes_count || 0) end)
      total_time_practiced = Enum.reduce(sessions, 0, fn session, acc -> acc + (session.time_taken || 0) end)
      
      update_attrs = %{
        total_tests: total_tests,
        average_wpm: Float.round(average_wpm, 2),
        average_accuracy: Float.round(average_accuracy, 2),
        best_wpm: best_wpm,
        best_accuracy: Float.round(best_accuracy, 2),
        total_keystrokes: total_keystrokes,
        total_mistakes: total_mistakes,
        total_time_practiced: total_time_practiced,
        last_practice_date: Date.utc_today()
      }

      case update_user_profile(profile, update_attrs) do
        {:ok, updated_profile} -> 
          update_daily_stats_from_sessions(user_profile_id)
          {:ok, updated_profile}
        error -> error
      end
    else
      {:ok, profile}
    end
  end

  # Original function for manual updates
  defp update_profile_stats(user_profile_id, session_data) do
    profile = Repo.get!(UserProfile, user_profile_id)
    
    new_total_tests = profile.total_tests + 1
    new_avg_wpm = ((profile.average_wpm * profile.total_tests) + session_data.wpm) / new_total_tests
    new_avg_accuracy = ((profile.average_accuracy * profile.total_tests) + session_data.accuracy) / new_total_tests
    
    update_attrs = %{
      total_tests: new_total_tests,
      average_wpm: Float.round(new_avg_wpm, 2),
      average_accuracy: Float.round(new_avg_accuracy, 2),
      best_wpm: max(profile.best_wpm, session_data.wpm),
      best_accuracy: max(profile.best_accuracy, session_data.accuracy),
      total_keystrokes: profile.total_keystrokes + (session_data[:total_keystrokes] || 0),
      total_mistakes: profile.total_mistakes + (session_data[:mistakes_count] || 0),
      total_time_practiced: profile.total_time_practiced + (session_data[:time_taken] || 0),
      last_practice_date: Date.utc_today()
    }

    update_user_profile(profile, update_attrs)
  end

  defp update_daily_stats_from_sessions(user_profile_id) do
    today = Date.utc_today()
    
    # Get today's sessions
    today_sessions = from(s in TypingSession,
      where: s.user_profile_id == ^user_profile_id,
      where: fragment("DATE(?)", s.completed_at) == ^today,
      select: %{
        wpm: s.wpm,
        accuracy: s.accuracy,
        mistakes_count: s.mistakes_count,
        total_keystrokes: s.total_keystrokes,
        time_taken: s.time_taken
      }
    ) |> Repo.all()

    if length(today_sessions) > 0 do
      sessions_count = length(today_sessions)
      
      total_wpm = Enum.reduce(today_sessions, 0, fn session, acc -> acc + (session.wpm || 0) end)
      average_wpm = total_wpm / sessions_count
      
      total_accuracy = Enum.reduce(today_sessions, 0, fn session, acc -> acc + (session.accuracy || 0) end)
      average_accuracy = total_accuracy / sessions_count
      
      best_wpm = Enum.reduce(today_sessions, 0, fn session, acc -> max(acc, session.wpm || 0) end)
      total_time = Enum.reduce(today_sessions, 0, fn session, acc -> acc + (session.time_taken || 0) end)
      total_keystrokes = Enum.reduce(today_sessions, 0, fn session, acc -> acc + (session.total_keystrokes || 0) end)
      total_mistakes = Enum.reduce(today_sessions, 0, fn session, acc -> acc + (session.mistakes_count || 0) end)

      daily_stat_attrs = %{
        user_profile_id: user_profile_id,
        practice_date: today,
        sessions_count: sessions_count,
        average_wpm: Float.round(average_wpm, 2),
        average_accuracy: Float.round(average_accuracy, 2),
        best_wpm: best_wpm,
        total_time: total_time,
        total_keystrokes: total_keystrokes,
        total_mistakes: total_mistakes
      }

      # Use Repo.insert with on_conflict to update or insert
      %DailyStat{}
      |> DailyStat.changeset(daily_stat_attrs)
      |> Repo.insert(on_conflict: {:replace, [:sessions_count, :average_wpm, :average_accuracy, :best_wpm, :total_time, :total_keystrokes, :total_mistakes, :updated_at]}, conflict_target: [:user_profile_id, :practice_date])
    end
  end

  defp update_daily_stats(user_profile_id, session_data) do
    today = Date.utc_today()
    
    daily_stat = Repo.get_by(DailyStat, user_profile_id: user_profile_id, practice_date: today)
    
    if daily_stat do
      new_sessions = daily_stat.sessions_count + 1
      new_avg_wpm = ((daily_stat.average_wpm * daily_stat.sessions_count) + session_data.wpm) / new_sessions
      new_avg_accuracy = ((daily_stat.average_accuracy * daily_stat.sessions_count) + session_data.accuracy) / new_sessions
      
      update_attrs = %{
        sessions_count: new_sessions,
        average_wpm: Float.round(new_avg_wpm, 2),
        average_accuracy: Float.round(new_avg_accuracy, 2),
        best_wpm: max(daily_stat.best_wpm, session_data.wpm),
        total_time: daily_stat.total_time + (session_data[:time_taken] || 0),
        total_keystrokes: daily_stat.total_keystrokes + (session_data[:total_keystrokes] || 0),
        total_mistakes: daily_stat.total_mistakes + (session_data[:mistakes_count] || 0)
      }
      
      daily_stat
      |> DailyStat.changeset(update_attrs)
      |> Repo.update()
    else
      %DailyStat{}
      |> DailyStat.changeset(%{
        user_profile_id: user_profile_id,
        practice_date: today,
        sessions_count: 1,
        average_wpm: session_data.wpm * 1.0,
        average_accuracy: session_data.accuracy * 1.0,
        best_wpm: session_data.wpm,
        total_time: session_data[:time_taken] || 0,
        total_keystrokes: session_data[:total_keystrokes] || 0,
        total_mistakes: session_data[:mistakes_count] || 0
      })
      |> Repo.insert()
    end
  end

  def get_user_profile_with_stats(user_id) do
    case Repo.get_by(UserProfile, user_id: user_id) do
      nil -> {:error, :not_found}
      profile -> 
        profile
        |> Repo.preload([:typing_sessions, :daily_stats, :character_mistakes])
        |> then(&{:ok, &1})
    end
  end

  def get_recent_sessions(user_profile_id, limit \\ 10) do
    from(s in TypingSession,
      where: s.user_profile_id == ^user_profile_id,
      order_by: [desc: s.completed_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_progress_data(user_profile_id, days \\ 30) do
    start_date = Date.add(Date.utc_today(), -days)
    
    from(d in DailyStat,
      where: d.user_profile_id == ^user_profile_id and d.practice_date >= ^start_date,
      order_by: [asc: d.practice_date]
    )
    |> Repo.all()
  end

  # Additional helper functions that might be needed
  def get_typing_sessions_for_profile(user_profile_id, limit \\ nil) do
    query = from(s in TypingSession,
      where: s.user_profile_id == ^user_profile_id,
      order_by: [desc: s.completed_at]
    )
    
    query = if limit, do: limit(query, ^limit), else: query
    
    Repo.all(query)
  end

  def get_daily_stats_for_profile(user_profile_id, days \\ 30) do
    start_date = Date.add(Date.utc_today(), -days)
    
    from(d in DailyStat,
      where: d.user_profile_id == ^user_profile_id and d.practice_date >= ^start_date,
      order_by: [desc: d.practice_date]
    )
    |> Repo.all()
  end

  def delete_user_profile(user_profile_id) do
    case Repo.get(UserProfile, user_profile_id) do
      nil -> {:error, :not_found}
      profile -> Repo.delete(profile)
    end
  end

  # Helper function to safely initialize default profile values
  def ensure_profile_defaults(%UserProfile{} = profile) do
    %{profile |
      total_tests: profile.total_tests || 0,
      average_wpm: profile.average_wpm || 0.0,
      average_accuracy: profile.average_accuracy || 0.0,
      best_wpm: profile.best_wpm || 0,
      best_accuracy: profile.best_accuracy || 0.0,
      total_keystrokes: profile.total_keystrokes || 0,
      total_mistakes: profile.total_mistakes || 0,
      total_time_practiced: profile.total_time_practiced || 0,
      streak_days: profile.streak_days || 0
    }
  end

  # Function to get or create profile with safe defaults
  def get_or_create_user_profile_safe(user_id) do
    case get_or_create_user_profile(user_id) do
      {:ok, profile} -> {:ok, ensure_profile_defaults(profile)}
      error -> error
    end
  end
end