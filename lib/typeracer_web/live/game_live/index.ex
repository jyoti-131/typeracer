defmodule TyperacerWeb.RaceLive.Index do
  use TyperacerWeb, :live_view
  
  alias Typeracer.Stats
  
  @sample_texts [
    "Typing is a skill that improves with regular practice and conscious effort. By repeating thoughtful sentences, one builds muscle memory and speed over time.",
    "In today's digital age, mastering the keyboard is as essential as holding a pen. Precision, rhythm, and familiarity with the layout are key elements of success.",
    "Many people underestimate the importance of proper hand positioning when learning to type. Resting your fingers on the home row builds a strong foundation.",
    "Focus and consistency lead to fluency. Typing is not just about speed — it's about accuracy and endurance as well.",
    "Good typists don't look at their keyboards. Instead, they train their minds and fingers to instinctively find each letter, comma, or period.",
    "Regular sessions, even if brief, are far more effective than long, inconsistent practice. Build a habit and your hands will follow.",
    "Most errors in typing come not from lack of skill, but from rushing. Slow down, build confidence, and then aim for speed.",
    "The keyboard is a language in itself. Every key, every shortcut, every tap becomes part of your communication toolkit.",
    "From essays to code, typing unlocks creativity and productivity. With mastery, you can let your ideas flow as fast as your thoughts.",
    "Fluency in typing is not achieved overnight. It takes time, patience, and hundreds of keystrokes that gradually turn into confidence."
  ]

  @difficulty_levels %{
    "beginner" => %{
      name: "Beginner",
      description: "Simple words and structured sentences",
      target_wpm: 25,
      texts: [
        "Cats like to nap in the sun near the big red mat.",
        "The dog barked at the cat who ran up the tree.",
        "It is fun to jump, run, skip, and play in the yard.",
        "Jane has a big blue ball that she likes to roll.",
        "The moon glows bright in the dark, clear sky.",
        "Books are fun to read when the day is slow.",
        "Dad made hot soup for lunch with bread and butter.",
        "Tom rides his bike to the park every day at ten."
      ]
    },
    "intermediate" => %{
      name: "Intermediate", 
      description: "Longer sentences with punctuation and flow",
      target_wpm: 40,
      texts: [
        "Typing is not about speed alone; it's about making fewer mistakes and building a rhythm.",
        "Many students struggle with punctuation because they rush through sentences without thinking.",
        "Every good typist knows that consistent practice — not perfection — leads to long-term growth.",
        "Do not let early mistakes discourage you: even expert typists hit the wrong key now and then.",
        "As your fingers learn the layout, your thoughts will move directly to the screen without delay.",
        "When typing becomes second nature, writing essays, emails, and code becomes far more enjoyable."
      ]
    },
    "advanced" => %{
      name: "Advanced",
      description: "Technical text with numbers, symbols, and code",
      target_wpm: 60,
      texts: [
        "In 2025, the AI market saw a 34.7% growth — totaling $342.6B in global revenue, as reported by Gartner.",
        "To install dependencies, run: `npm install && npm run build` from the root project directory.",
        "Here's a sample JSON payload: { \"user\": \"admin\", \"role\": \"editor\", \"active\": true }",
        "Use the formula `y = mx + b` to calculate the linear relationship between variables in regression.",
        "Error: Cannot read properties of undefined (reading 'map') — check your `null` checks and input values.",
        "ssh-keygen -t rsa -b 4096 -C \"your_email@example.com\" is a standard way to generate a secure SSH key pair."
      ]
    }
  }

  @keyboard_layout [
    ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="],
    ["Tab", "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", "\\"],
    ["CapsLock", "a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'", "Enter"],
    ["Shift", "z", "x", "c", "v", "b", "n", "m", ",", ".", "/", "Shift"],
    ["Ctrl", "Meta", "Alt", "Space", "Alt", "Meta", "Menu", "Ctrl"]
  ]

  @impl true
  def mount(_params, session, socket) do
    IO.puts("RaceLive mount called with session: #{inspect(session)}")
    
    # FIXED: Properly handle session-based user ID with enhanced error handling
    user_id = case session["user_id"] do
      nil -> 
        # Generate new user ID if not in session
        id = "user_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16())
        IO.puts("Generated new user_id: #{id}")
        id
      existing_id -> 
        IO.puts("Using existing user_id from session: #{existing_id}")
        existing_id
    end
    
    # Get or create user profile with better error handling
    {profile, profile_created} = case Stats.get_or_create_user_profile(user_id) do
      {:ok, profile} -> 
        IO.puts("Profile loaded successfully: #{inspect(profile)}")
        {profile, false}
      {:error, reason} -> 
        IO.puts("Error creating user profile: #{inspect(reason)}")
        # Create a default profile structure to prevent crashes
        default_profile = %{
          id: nil,
          user_id: user_id,
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
        {default_profile, true}
    end
    
    socket = 
      socket
      |> assign(:user_id, user_id)
      |> assign(:user_profile, profile)
      |> assign(:profile_created, profile_created)
      |> assign(:practice_mode, :difficulty_select)
      |> assign(:selected_difficulty, "intermediate")
      |> assign(:current_text, "")
      |> assign(:typed_text, "")
      |> assign(:current_position, 0)
      |> assign(:accuracy, 100)
      |> assign(:wpm, 0)
      |> assign(:start_time, nil)
      |> assign(:elapsed_time, 0)
      |> assign(:is_finished, false)
      |> assign(:practice_started, false)
      |> assign(:character_states, [])
      |> assign(:current_word_index, 0)
      |> assign(:words, [])
      |> assign(:word_states, [])
      |> assign(:current_char_to_type, "")
      |> assign(:next_char_to_highlight, "")
      |> assign(:session_stats, %{
        total_tests: profile.total_tests || 0,
        avg_wpm: round(profile.average_wpm || 0),
        avg_accuracy: round(profile.average_accuracy || 0),
        best_wpm: profile.best_wpm || 0
      })
      |> assign(:current_test_number, 1)
      |> assign(:mistakes_count, 0)
      |> assign(:total_keystrokes, 0)
      |> assign(:save_error, nil)
      |> assign(:needs_session_storage, session["user_id"] == nil)
    
    {:ok, socket}
  end

  # FIXED: Handle the message to store user_id in session (keeping for compatibility)
  @impl true
  def handle_info({:store_user_id, user_id}, socket) do
    # Use push_event to store user_id in session storage on client side
    socket = push_event(socket, "store_session", %{user_id: user_id})
    {:noreply, socket}
  end

  # FIXED: Enhanced profile navigation with proper session handling
  @impl true
  def handle_event("view_profile", _params, socket) do
    user_id = socket.assigns.user_id
    profile = socket.assigns.user_profile
    
    IO.puts("Navigating to profile with user_id: #{user_id}")
    IO.puts("Profile data: #{inspect(profile)}")
    
    # FIXED: Simple navigation - let the router session management handle the user_id persistence
    # The session is already managed by the router, so we just navigate
    {:noreply, push_navigate(socket, to: ~p"/profile")}
  end

  # Handle multiplayer race start
  @impl true
  def handle_event("start_multiplayer", _params, socket) do
    room_id = Ecto.UUID.generate()  # or use :crypto.strong_rand_bytes(16) |> Base.encode16()
    {:noreply, push_navigate(socket, to: "/race/room/#{room_id}")}
  end

  @impl true
  def handle_event("select_difficulty", %{"difficulty" => difficulty}, socket) do
    difficulty_config = @difficulty_levels[difficulty]
    text = Enum.random(difficulty_config.texts)
    words = String.split(text, " ")
    
    socket = 
      socket
      |> assign(:practice_mode, :practice)
      |> assign(:selected_difficulty, difficulty)
      |> assign(:current_text, text)
      |> assign(:typed_text, "")
      |> assign(:current_position, 0)
      |> assign(:accuracy, 100)
      |> assign(:wpm, 0)
      |> assign(:start_time, :os.system_time(:millisecond))
      |> assign(:elapsed_time, 0)
      |> assign(:is_finished, false)
      |> assign(:practice_started, true)
      |> assign(:character_states, initialize_character_states(text))
      |> assign(:words, words)
      |> assign(:word_states, initialize_word_states(words))
      |> assign(:current_word_index, 0)
      |> assign(:current_char_to_type, get_char_at_position(text, 0))
      |> assign(:next_char_to_highlight, get_char_for_keyboard_highlight(text, 0))
      |> assign(:mistakes_count, 0)
      |> assign(:total_keystrokes, 0)
      |> assign(:save_error, nil)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_exercise", _params, socket) do
    # Save current session if finished
    socket = if socket.assigns.is_finished do
      save_typing_session(socket)
    else
      socket
    end
    
    difficulty = socket.assigns.selected_difficulty
    difficulty_config = @difficulty_levels[difficulty]
    text = Enum.random(difficulty_config.texts)
    words = String.split(text, " ")
    
    # Update session stats with fresh profile data - FIXED: Better error handling
    updated_profile = case socket.assigns.user_profile.id do
      nil -> socket.assigns.user_profile
      profile_id ->
        case Stats.get_user_profile(profile_id) do
          {:ok, profile} -> profile
          {:error, _} -> socket.assigns.user_profile
        end
    end
    
    updated_stats = %{
      total_tests: updated_profile.total_tests || 0,
      avg_wpm: round(updated_profile.average_wpm || 0),
      avg_accuracy: round(updated_profile.average_accuracy || 0),
      best_wpm: updated_profile.best_wpm || 0
    }
    
    socket = 
      socket
      |> assign(:user_profile, updated_profile)
      |> assign(:current_text, text)
      |> assign(:typed_text, "")
      |> assign(:current_position, 0)
      |> assign(:accuracy, 100)
      |> assign(:wpm, 0)
      |> assign(:start_time, :os.system_time(:millisecond))
      |> assign(:elapsed_time, 0)
      |> assign(:is_finished, false)
      |> assign(:practice_started, true)
      |> assign(:character_states, initialize_character_states(text))
      |> assign(:words, words)
      |> assign(:word_states, initialize_word_states(words))
      |> assign(:current_word_index, 0)
      |> assign(:current_char_to_type, get_char_at_position(text, 0))
      |> assign(:next_char_to_highlight, get_char_for_keyboard_highlight(text, 0))
      |> assign(:session_stats, updated_stats)
      |> assign(:current_test_number, socket.assigns.current_test_number + 1)
      |> assign(:mistakes_count, 0)
      |> assign(:total_keystrokes, 0)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_difficulty", _params, socket) do
    socket = 
      socket
      |> assign(:practice_mode, :difficulty_select)
      |> assign(:current_text, "")
      |> assign(:typed_text, "")
      |> assign(:current_position, 0)
      |> assign(:practice_started, false)
      |> assign(:is_finished, false)
    
    {:noreply, socket}
  end

  # Main keystroke handler - PRIMARY EVENT HANDLER
  @impl true
  def handle_event("handle_keystroke", %{"key" => key}, socket) do
    if socket.assigns.practice_started and not socket.assigns.is_finished do
      handle_key_input(socket, key)
    else
      {:noreply, socket}
    end
  end

  # Handle keydown events - SECONDARY EVENT HANDLER (for frontend compatibility)
  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    if socket.assigns.practice_started and not socket.assigns.is_finished do
      handle_key_input(socket, key)
    else
      {:noreply, socket}
    end
  end

  # Handle keyup events - IGNORED to prevent double processing
  @impl true
  def handle_event("keyup", %{"key" => _key}, socket) do
    {:noreply, socket}
  end

  # Handle focus event for the invisible input
  @impl true
  def handle_event("focus_input", _, socket) do
    {:noreply, socket}
  end

  # Handle any other typing events (fallback) - but ignore them to prevent double processing
  @impl true
  def handle_event("typing", %{"value" => _input}, socket) do
    # We ignore this since we handle keystrokes directly
    {:noreply, socket}
  end

  # Main key input handler - MODIFIED to disable backspace
  defp handle_key_input(socket, key) do
    current_position = socket.assigns.current_position
    current_text = socket.assigns.current_text
    text_length = String.length(current_text)
    
    cond do
      # DISABLED: Backspace functionality completely removed
      key == "Backspace" ->
        # Ignore backspace - do not allow corrections
        {:noreply, socket}
      
      # Handle regular printable characters (single character only)
      # Filter out modifier keys and special keys
      String.length(key) == 1 and current_position < text_length and 
      key not in ["Shift", "Control", "Alt", "Meta", "CapsLock", "Tab", "Enter", "Escape"] ->
        handle_character_input(socket, key)
      
      # Handle Space specifically (it has length 1 but is special)
      key == " " and current_position < text_length ->
        handle_character_input(socket, " ")
      
      # Ignore all other keys (including Shift, Ctrl, Alt, etc.)
      true ->
        {:noreply, socket}
    end
  end

  # Handle character input - NO CHANGES NEEDED HERE
  defp handle_character_input(socket, typed_char) do
    current_position = socket.assigns.current_position
    current_text = socket.assigns.current_text
    expected_char = get_char_at_position(current_text, current_position)
    
    # Always advance position and update typed text
    new_position = current_position + 1
    new_typed_text = socket.assigns.typed_text <> typed_char
    
    # Track total keystrokes
    new_total_keystrokes = socket.assigns.total_keystrokes + 1
    
    # Count mistake if characters don't match
    new_mistakes_count = if typed_char != expected_char do
      socket.assigns.mistakes_count + 1
    else
      socket.assigns.mistakes_count
    end
    
    socket = 
      socket
      |> assign(:current_position, new_position)
      |> assign(:typed_text, new_typed_text)
      |> assign(:total_keystrokes, new_total_keystrokes)
      |> assign(:mistakes_count, new_mistakes_count)
      |> assign(:current_char_to_type, get_char_at_position(current_text, new_position))
      |> assign(:next_char_to_highlight, get_char_for_keyboard_highlight(current_text, new_position))
      |> update_character_states()
      |> calculate_real_time_stats()
    
    # Check if finished
    socket = if new_position >= String.length(current_text) do
      finish_exercise(socket)
    else
      socket
    end
    
    {:noreply, socket}
  end

  # FIXED: Private function to save typing session with better error handling
  defp save_typing_session(socket) do
    # Only save if we have a valid profile ID
    case socket.assigns.user_profile.id do
      nil ->
        IO.puts("Cannot save session: No valid profile ID")
        assign(socket, :save_error, "No valid user profile")
      
      profile_id ->
        session_attrs = %{
          user_profile_id: profile_id,
          difficulty: socket.assigns.selected_difficulty,
          text_content: socket.assigns.current_text,
          wpm: socket.assigns.wpm,
          accuracy: socket.assigns.accuracy,
          mistakes_count: socket.assigns.mistakes_count,
          total_keystrokes: socket.assigns.total_keystrokes,
          time_taken: socket.assigns.elapsed_time,
          completed_at: DateTime.utc_now()
        }

        IO.puts("Attempting to save typing session: #{inspect(session_attrs)}")

        case Stats.create_typing_session(session_attrs) do
          {:ok, session} ->
            IO.puts("Successfully saved typing session: #{inspect(session)}")
            
            # Update user profile stats
            case Stats.update_user_profile_stats(profile_id) do
              {:ok, updated_profile} ->
                IO.puts("Successfully updated profile stats: #{inspect(updated_profile)}")
                assign(socket, :user_profile, updated_profile)
              {:error, reason} ->
                IO.puts("Error updating profile stats: #{inspect(reason)}")
                assign(socket, :save_error, "Failed to update profile statistics")
            end
            
          {:error, changeset} ->
            IO.puts("Error saving typing session: #{inspect(changeset)}")
            assign(socket, :save_error, "Failed to save typing session")
        end
    end
  end

  # Helper functions
  defp get_char_at_position(text, position) do
    if position < String.length(text) do
      String.at(text, position) || ""
    else
      ""
    end
  end

  # Get character for keyboard highlighting (handle special cases)
  defp get_char_for_keyboard_highlight(text, position) do
    char = get_char_at_position(text, position)
    case char do
      " " -> "Space"
      "\t" -> "Tab"
      "\n" -> "Enter"
      other -> String.downcase(other)
    end
  end

  # Update character states based on current typing - NO CHANGES NEEDED
  defp update_character_states(socket) do
    current_text = socket.assigns.current_text
    typed_text = socket.assigns.typed_text
    current_position = socket.assigns.current_position
    
    character_states = 
      current_text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, index} ->
        state = cond do
          index < String.length(typed_text) ->
            typed_char = String.at(typed_text, index)
            if typed_char == char, do: :correct, else: :incorrect
          index == current_position ->
            :current
          true ->
            :untyped
        end
        
        %{character: char, index: index, state: state}
      end)
    
    assign(socket, character_states: character_states)
  end

  # Calculate real-time stats - NO CHANGES NEEDED
  defp calculate_real_time_stats(socket) do
    if socket.assigns.start_time do
      elapsed_milliseconds = :os.system_time(:millisecond) - socket.assigns.start_time
      elapsed_seconds = elapsed_milliseconds / 1000
      
      # Update elapsed time
      socket = assign(socket, :elapsed_time, round(elapsed_seconds))
      
      if elapsed_seconds > 0 do
        # Calculate accuracy based on correct characters vs total keystrokes
        correct_chars = socket.assigns.character_states
        |> Enum.count(fn char_data -> char_data.state == :correct end)
        
        total_keystrokes = socket.assigns.total_keystrokes
        
        accuracy = if total_keystrokes > 0 do
          round((correct_chars / total_keystrokes) * 100)
        else
          100
        end
        
        # Calculate WPM based on correct characters
        words_typed = correct_chars / 5.0
        wpm = round(words_typed / (elapsed_seconds / 60.0))
        
        assign(socket, wpm: max(0, wpm), accuracy: accuracy)
      else
        socket
      end
    else
      socket
    end
  end

  # Finish exercise - IMPROVED SAVING
  defp finish_exercise(socket) do
    socket = calculate_real_time_stats(socket)
    
    # Save the session automatically when finished
    socket = save_typing_session(socket)
    
    assign(socket, is_finished: true)
  end

  # Helper function to format time
  defp format_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    
    cond do
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end

  # Helper functions for the template
  defp get_difficulty_name(difficulty) do
    @difficulty_levels[difficulty].name
  end

  defp get_difficulty_description(difficulty) do
    @difficulty_levels[difficulty].description
  end

  defp get_target_wpm(difficulty) do
    @difficulty_levels[difficulty].target_wpm
  end

  def get_keyboard_layout, do: @keyboard_layout

  # Initialize character states
  defp initialize_character_states(text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, index} -> 
      state = if index == 0, do: :current, else: :untyped
      %{character: char, index: index, state: state}
    end)
  end

  # Initialize word states (keeping for compatibility)
  defp initialize_word_states(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, index} ->
      %{word: word, index: index, state: :untyped}
    end)
  end

  defp get_performance_message(wpm, target_wpm) do
    cond do
      wpm >= target_wpm + 10 -> "🌟 Excellent! You exceeded expectations!"
      wpm >= target_wpm -> "✅ Great job! You hit the target speed!"
      wpm >= target_wpm - 10 -> "👍 Good progress! Almost there!"
      true -> "💪 Keep practicing! You're improving!"
    end
  end

  defp get_accuracy_message(accuracy) do
    cond do
      accuracy >= 98 -> "🎯 Perfect accuracy!"
      accuracy >= 95 -> "✨ Excellent accuracy!"
      accuracy >= 90 -> "👍 Good accuracy!"
      accuracy >= 85 -> "📈 Decent accuracy, keep improving!"
      true -> "🎯 Focus on accuracy over speed!"
    end
  end

  # Legacy functions for compatibility - can be removed if not used in template
  defp count_correct_characters(character_states) do
    character_states
    |> Enum.count(fn %{state: state} -> state == :correct end)
  end

  defp count_mistakes(character_states) do
    character_states
    |> Enum.count(fn %{state: state} -> state == :incorrect end)
  end

  defp calculate_wpm(start_time, correct_chars) do
    if start_time do
      elapsed_minutes = (:os.system_time(:millisecond) - start_time) / 60_000
      if elapsed_minutes > 0 do
        round(correct_chars / 5 / elapsed_minutes)
      else
        0
      end
    else
      0
    end
  end
end