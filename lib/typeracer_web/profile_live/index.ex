defmodule TyperacerWeb.ProfileLive.Index do
  use TyperacerWeb, :live_view
  
  alias Typeracer.Stats

  def mount(_params, session, socket) do
    IO.puts("ProfileLive mount called with session: #{inspect(session)}")
    
    # FIXED: Enhanced session handling with better error recovery
    case session["user_id"] do
      nil -> 
        IO.puts("No user_id in session, checking connect_params")
        # Try to get user_id from connect_params as fallback
        case get_socket_connect_params(socket) do
          %{"user_id" => user_id} ->
            IO.puts("Found user_id in connect_params: #{user_id}")
            mount_with_user_id(socket, user_id)
          _ ->
            IO.puts("No user_id found anywhere, redirecting to race")
            {:ok, push_navigate(socket, to: ~p"/")}
        end
      existing_id -> 
        IO.puts("Found user_id in session: #{existing_id}")
        # Continue with mounting using the existing user_id
        mount_with_user_id(socket, existing_id)
    end
  end

  # Add this helper function to get connect params
  defp get_socket_connect_params(socket) do
    case socket.assigns do
      %{connect_params: params} -> params
      _ -> %{}
    end
  end

  defp mount_with_user_id(socket, user_id) do
    IO.puts("Mounting profile with user_id: #{user_id}")
    
    # FIXED: Enhanced profile loading with better error handling
    {profile, recent_sessions, progress_data} = case Stats.get_or_create_user_profile(user_id) do
      {:ok, profile} ->
        IO.puts("Profile loaded successfully: #{inspect(profile)}")
        
        # FIXED: Only try to get sessions if we have a valid profile ID
        recent_sessions = case profile.id do
          nil -> 
            IO.puts("Profile has no ID, using empty sessions")
            []
          profile_id ->
            case Stats.get_recent_sessions(profile_id, 10) do
              sessions when is_list(sessions) -> 
                IO.puts("Loaded #{length(sessions)} recent sessions")
                sessions
              {:error, reason} -> 
                IO.puts("Error loading sessions: #{inspect(reason)}")
                []
              _ -> 
                IO.puts("Unexpected response for sessions")
                []
            end
        end
        
        # FIXED: Only try to get progress data if we have a valid profile ID
        progress_data = case profile.id do
          nil -> 
            IO.puts("Profile has no ID, using empty progress data")
            []
          profile_id ->
            case Stats.get_progress_data(profile_id, 7) do
              data when is_list(data) -> 
                IO.puts("Loaded #{length(data)} progress data points")
                data
              {:error, reason} -> 
                IO.puts("Error loading progress data: #{inspect(reason)}")
                []
              _ -> 
                IO.puts("Unexpected response for progress data")
                []
            end
        end
        
        {profile, recent_sessions, progress_data}
        
      {:error, reason} ->
        IO.puts("Error getting user profile: #{inspect(reason)}")
        # Create a more complete default profile structure
        default_profile = %{
          id: nil,
          user_id: user_id,
          username: nil,
          total_tests: 0,
          average_wpm: 0.0,
          average_accuracy: 0.0,
          best_wpm: 0,
          total_keystrokes: 0,
          total_mistakes: 0,
          best_accuracy: 0.0,
          total_time_practiced: 0,
          favorite_difficulty: "intermediate",
          streak_days: 0,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
        {default_profile, [], []}
    end
    
    # Calculate additional stats with safety checks
    activity_summary = get_activity_summary(recent_sessions)
    improvement_trend = get_improvement_trend(progress_data)
    
    IO.puts("Profile mount successful, assigning to socket")
    
    socket = 
      socket
      |> assign(:user_profile, profile)
      |> assign(:user_id, user_id)
      |> assign(:active_tab, :overview)
      |> assign(:recent_sessions, recent_sessions)
      |> assign(:progress_data, progress_data)
      |> assign(:activity_summary, activity_summary)
      |> assign(:improvement_trend, improvement_trend)
      |> assign(:loading_error, nil)
      |> assign(:profile_loaded, true)
      |> assign(:editing_name, false)
      |> assign(:temp_username, get_display_name(profile))
    
    IO.puts("Socket assignments complete")
    {:ok, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    IO.puts("Switching to tab: #{tab}")
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  # Update the back_to_practice handler to preserve session
  def handle_event("back_to_practice", _params, socket) do
    IO.puts("Navigating back to practice with user_id: #{socket.assigns.user_id}")
    
    # Ensure we preserve the user_id in session when going back
    socket = put_session(socket, "user_id", socket.assigns.user_id)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("refresh_data", _params, socket) do
    IO.puts("Refreshing profile data")
    # Refresh profile data
    user_id = socket.assigns.user_id
    
    case Stats.get_or_create_user_profile(user_id) do
      {:ok, updated_profile} ->
        IO.puts("Profile refreshed successfully")
        
        # FIXED: Only refresh sessions if we have a valid profile ID
        recent_sessions = case updated_profile.id do
          nil -> socket.assigns.recent_sessions
          profile_id ->
            case Stats.get_recent_sessions(profile_id, 10) do
              sessions when is_list(sessions) -> sessions
              _ -> socket.assigns.recent_sessions
            end
        end
        
        # FIXED: Only refresh progress data if we have a valid profile ID
        progress_data = case updated_profile.id do
          nil -> socket.assigns.progress_data
          profile_id ->
            case Stats.get_progress_data(profile_id, 7) do
              data when is_list(data) -> data
              _ -> socket.assigns.progress_data
            end
        end
        
        # Recalculate derived stats
        activity_summary = get_activity_summary(recent_sessions)
        improvement_trend = get_improvement_trend(progress_data)
        
        socket = 
          socket
          |> assign(:user_profile, updated_profile)
          |> assign(:recent_sessions, recent_sessions)
          |> assign(:progress_data, progress_data)
          |> assign(:activity_summary, activity_summary)
          |> assign(:improvement_trend, improvement_trend)
          |> assign(:loading_error, nil)
        
        {:noreply, socket}
        
      {:error, reason} ->
        IO.puts("Error refreshing profile data: #{inspect(reason)}")
        socket = assign(socket, :loading_error, "Failed to refresh data")
        {:noreply, socket}
    end
  end

  # FIXED: Handle name editing events
  def handle_event("start_edit_name", _params, socket) do
    current_name = get_display_name(socket.assigns.user_profile)
    socket = 
      socket
      |> assign(:editing_name, true)
      |> assign(:temp_username, current_name)
    
    {:noreply, socket}
  end

  def handle_event("cancel_edit_name", _params, socket) do
    socket = assign(socket, :editing_name, false)
    {:noreply, socket}
  end

  # FIXED: Handle keyup event from form input
  def handle_event("update_temp_username", %{"value" => username}, socket) do
    # Validate username (basic validation)
    cleaned_username = String.trim(username)
    
    socket = assign(socket, :temp_username, cleaned_username)
    {:noreply, socket}
  end

  # FIXED: Also handle the case where the event comes with different key
  def handle_event("update_temp_username", %{"_target" => ["username"], "username" => username}, socket) do
    cleaned_username = String.trim(username)
    socket = assign(socket, :temp_username, cleaned_username)
    {:noreply, socket}
  end

  # FIXED: Handle form submission properly
  def handle_event("save_username", %{"username" => username}, socket) do
    save_username_handler(socket, username)
  end

  # Handle case where form might not have username field
  def handle_event("save_username", _params, socket) do
    save_username_handler(socket, socket.assigns.temp_username)
  end

  # FIXED: Extracted save username logic to reusable function
  defp save_username_handler(socket, username) do
    username = String.trim(username)
    
    # Basic validation
    cond do
      String.length(username) == 0 ->
        # Don't save empty username, just cancel editing
        socket = assign(socket, :editing_name, false)
        {:noreply, socket}
        
      String.length(username) > 50 ->
        # Username too long - show error but keep editing mode
        IO.puts("Username too long: #{String.length(username)} characters")
        {:noreply, socket}
        
      true ->
        # Save the username
        case save_username_to_profile(socket.assigns.user_profile, username) do
          {:ok, updated_profile} ->
            IO.puts("Username updated successfully to: #{username}")
            socket = 
              socket
              |> assign(:user_profile, updated_profile)
              |> assign(:editing_name, false)
              |> assign(:temp_username, username)
            
            {:noreply, socket}
            
          {:error, reason} ->
            IO.puts("Error updating username: #{inspect(reason)}")
            # Keep editing mode but could show error message
            {:noreply, socket}
        end
    end
  end

  # Add the session helper function
  defp put_session(socket, key, value) do
    # Note: put_connect_params doesn't actually modify session
    # This is a placeholder - in LiveView, session is read-only after mount
    # The session management should be handled by the router plug
    socket
  end

  # FIXED: Helper to save username to profile with actual database call
  defp save_username_to_profile(profile, username) do
    case profile.id do
      nil ->
        # If no profile ID, we can't save to database, but we can update the struct
        IO.puts("No profile ID, updating struct only")
        updated_profile = Map.put(profile, :username, username)
        {:ok, updated_profile}
      
      profile_id ->
        # FIXED: Make actual database update call
        IO.puts("Updating profile #{profile_id} with username: #{username}")
        
        case Stats.update_user_profile(profile, %{username: username}) do
          {:ok, updated_profile} ->
            IO.puts("Successfully updated username in database")
            {:ok, updated_profile}
          {:error, changeset} ->
            IO.puts("Database update failed: #{inspect(changeset)}")
            {:error, changeset}
        end
    end
  end

  # FIXED: Helper to get display name
  defp get_display_name(profile) do
    case profile do
      %{username: username} when is_binary(username) and username != "" -> 
        username
      _ -> 
        "Anonymous Typist"
    end
  end

  # FIXED: Helper to get avatar letter(s)
  defp get_avatar_letters(profile) do
    display_name = get_display_name(profile)
    
    case display_name do
      "Anonymous Typist" -> 
        "AT"
      name when is_binary(name) ->
        name
        |> String.trim()
        |> String.split()
        |> case do
          [] -> "U"
          [single] -> String.first(single) |> String.upcase()
          [first | rest] -> 
            first_letter = String.first(first) |> String.upcase()
            last_letter = List.last(rest) |> String.first() |> String.upcase()
            "#{first_letter}#{last_letter}"
        end
      _ -> 
        "U"
    end
  end

  # FIXED: Helper to get avatar color based on name
  defp get_avatar_color(profile) do
    name = get_display_name(profile)
    
    # Generate consistent color based on name hash
    hash = :erlang.phash2(name)
    
    colors = [
      "from-blue-500 to-purple-600",
      "from-green-500 to-teal-600", 
      "from-red-500 to-pink-600",
      "from-yellow-500 to-orange-600",
      "from-purple-500 to-indigo-600",
      "from-teal-500 to-cyan-600",
      "from-pink-500 to-rose-600",
      "from-indigo-500 to-blue-600"
    ]
    
    Enum.at(colors, rem(hash, length(colors)))
  end

  # Helper functions with better error handling
  defp format_time(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    
    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m"
      true -> "#{seconds}s"
    end
  end

  defp format_time(seconds) when is_float(seconds) do
    format_time(round(seconds))
  end

  defp format_time(_), do: "0s"

  defp format_date(%DateTime{} = date) do
    Calendar.strftime(date, "%b %d, %Y at %I:%M %p")
  end

  defp format_date(%NaiveDateTime{} = date) do
    Calendar.strftime(date, "%b %d, %Y at %I:%M %p")
  end

  defp format_date(date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, datetime, _} -> format_date(datetime)
      _ -> date
    end
  end

  defp format_date(_), do: "Unknown"

  # Helper to format difficulty levels
  defp format_difficulty(difficulty) when is_binary(difficulty) do
    difficulty
    |> String.capitalize()
  end

  defp format_difficulty(_), do: "Unknown"

  # Helper to get difficulty color class
  defp difficulty_color_class("beginner"), do: "text-green-600 bg-green-100"
  defp difficulty_color_class("intermediate"), do: "text-yellow-600 bg-yellow-100"
  defp difficulty_color_class("advanced"), do: "text-red-600 bg-red-100"
  defp difficulty_color_class(_), do: "text-gray-600 bg-gray-100"

  # Helper to calculate improvement percentage
  defp calculate_improvement(current, previous) when is_number(current) and is_number(previous) and previous > 0 do
    improvement = ((current - previous) / previous) * 100
    round(improvement)
  end

  defp calculate_improvement(_, _), do: 0

  # Helper to format WPM with one decimal place
  defp format_wpm(wpm) when is_float(wpm) do
    :erlang.float_to_binary(wpm, decimals: 1)
  end

  defp format_wpm(wpm) when is_integer(wpm) do
    Integer.to_string(wpm)
  end

  defp format_wpm(_), do: "0"

  # Helper to format accuracy percentage
  defp format_accuracy(accuracy) when is_float(accuracy) do
    "#{:erlang.float_to_binary(accuracy, decimals: 1)}%"
  end

  defp format_accuracy(accuracy) when is_integer(accuracy) do
    "#{accuracy}%"
  end

  defp format_accuracy(_), do: "0%"

  # Helper to get performance badge
  defp get_performance_badge(wpm) when is_number(wpm) do
    cond do
      wpm >= 80 -> %{text: "Expert", class: "bg-purple-100 text-purple-800"}
      wpm >= 60 -> %{text: "Advanced", class: "bg-red-100 text-red-800"}
      wpm >= 40 -> %{text: "Intermediate", class: "bg-yellow-100 text-yellow-800"}
      wpm >= 25 -> %{text: "Beginner", class: "bg-green-100 text-green-800"}
      true -> %{text: "Novice", class: "bg-gray-100 text-gray-800"}
    end
  end

  defp get_performance_badge(_), do: %{text: "Novice", class: "bg-gray-100 text-gray-800"}

  # Helper to get accuracy badge
  defp get_accuracy_badge(accuracy) when is_number(accuracy) do
    cond do
      accuracy >= 98 -> %{text: "Perfect", class: "bg-green-100 text-green-800"}
      accuracy >= 95 -> %{text: "Excellent", class: "bg-blue-100 text-blue-800"}
      accuracy >= 90 -> %{text: "Good", class: "bg-yellow-100 text-yellow-800"}
      accuracy >= 85 -> %{text: "Fair", class: "bg-orange-100 text-orange-800"}
      true -> %{text: "Needs Work", class: "bg-red-100 text-red-800"}
    end
  end

  defp get_accuracy_badge(_), do: %{text: "Needs Work", class: "bg-red-100 text-red-800"}

  # Helper to check if profile has data
  defp has_profile_data?(profile) do
    profile && (profile.total_tests || 0) > 0
  end

  # Helper to format practice streak (if you add this feature later)
  defp format_streak(days) when is_integer(days) and days > 0 do
    case days do
      1 -> "1 day"
      n -> "#{n} days"
    end
  end

  defp format_streak(_), do: "0 days"

  # FIXED: Helper to get recent activity summary with enhanced safety checks
  defp get_activity_summary(recent_sessions) when is_list(recent_sessions) do
    if length(recent_sessions) > 0 do
      # Safely extract time data
      total_time = recent_sessions
      |> Enum.map(fn session -> 
        case session do
          %{time_taken: time} when is_number(time) -> time
          _ -> 0
        end
      end)
      |> Enum.sum()
      
      # Safely calculate average WPM
      wpm_values = recent_sessions
      |> Enum.map(fn session -> 
        case session do
          %{wpm: wpm} when is_number(wpm) -> wpm
          _ -> 0
        end
      end)
      |> Enum.filter(fn wpm -> wpm > 0 end)
      
      avg_wpm = case wpm_values do
        [] -> 0
        values -> round(Enum.sum(values) / length(values))
      end
      
      # Safely calculate average accuracy
      accuracy_values = recent_sessions
      |> Enum.map(fn session -> 
        case session do
          %{accuracy: accuracy} when is_number(accuracy) -> accuracy
          _ -> 0
        end
      end)
      |> Enum.filter(fn acc -> acc > 0 end)
      
      avg_accuracy = case accuracy_values do
        [] -> 0
        values -> round(Enum.sum(values) / length(values))
      end
      
      %{
        sessions_count: length(recent_sessions),
        total_time: total_time,
        avg_wpm: avg_wpm,
        avg_accuracy: avg_accuracy
      }
    else
      %{
        sessions_count: 0,
        total_time: 0,
        avg_wpm: 0,
        avg_accuracy: 0
      }
    end
  end

  defp get_activity_summary(_), do: %{sessions_count: 0, total_time: 0, avg_wpm: 0, avg_accuracy: 0}

  # FIXED: Helper to determine if user is improving with enhanced safety checks
  defp is_improving?(progress_data) when is_list(progress_data) and length(progress_data) >= 2 do
    recent_sessions = Enum.take(progress_data, 5)
    older_sessions = Enum.drop(progress_data, 5) |> Enum.take(5)
    
    if length(recent_sessions) > 0 and length(older_sessions) > 0 do
      recent_wpm_values = recent_sessions
      |> Enum.map(fn session -> 
        case session do
          %{average_wpm: wpm} when is_number(wpm) -> wpm
          %{wpm: wpm} when is_number(wpm) -> wpm
          _ -> 0
        end
      end)
      |> Enum.filter(fn wpm -> wpm > 0 end)
      
      older_wpm_values = older_sessions
      |> Enum.map(fn session -> 
        case session do
          %{average_wpm: wpm} when is_number(wpm) -> wpm
          %{wpm: wpm} when is_number(wpm) -> wpm
          _ -> 0
        end
      end)
      |> Enum.filter(fn wpm -> wpm > 0 end)
      
      recent_avg = case recent_wpm_values do
        [] -> 0
        values -> Enum.sum(values) / length(values)
      end
      
      older_avg = case older_wpm_values do
        [] -> 0
        values -> Enum.sum(values) / length(values)
      end
      
      recent_avg > older_avg
    else
      false
    end
  end

  defp is_improving?(_), do: false

  # Helper to get improvement trend
  defp get_improvement_trend(progress_data) when is_list(progress_data) do
    if is_improving?(progress_data) do
      %{trending: :up, message: "You're improving! Keep it up! 📈"}
    else
      %{trending: :stable, message: "Keep practicing to see improvement! 💪"}
    end
  end

  defp get_improvement_trend(_) do
    %{trending: :stable, message: "Start practicing to track your progress! 🚀"}
  end

  # Helper to get last practice date
  defp get_last_practice_date(recent_sessions) when is_list(recent_sessions) do
    case recent_sessions do
      [latest | _] ->
        case latest do
          %{completed_at: date} -> format_date(date)
          %{inserted_at: date} -> format_date(date)
          _ -> "Never"
        end
      _ -> "Never"
    end
  end

  defp get_last_practice_date(_), do: "Never"

  # Helper to calculate total practice time in a readable format
  defp calculate_total_practice_time(recent_sessions) when is_list(recent_sessions) do
    total_seconds = recent_sessions
    |> Enum.map(fn session ->
      case session do
        %{time_taken: time} when is_number(time) -> time
        _ -> 0
      end
    end)
    |> Enum.sum()
    
    format_time(total_seconds)
  end

  defp calculate_total_practice_time(_), do: "0s"

  # Helper to get best session from recent sessions
  defp get_best_recent_session(recent_sessions) when is_list(recent_sessions) do
    case recent_sessions do
      [] -> nil
      sessions ->
        sessions
        |> Enum.filter(fn session ->
          case session do
            %{wpm: wpm} when is_number(wpm) and wpm > 0 -> true
            _ -> false
          end
        end)
        |> case do
          [] -> nil
          valid_sessions ->
            Enum.max_by(valid_sessions, fn session ->
              case session do
                %{wpm: wpm} when is_number(wpm) -> wpm
                _ -> 0
              end
            end)
        end
    end
  end

  defp get_best_recent_session(_), do: nil
end