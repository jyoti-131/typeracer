defmodule TyperacerWeb.GameLive.RaceRoomLive do
  use TyperacerWeb, :live_view
  alias Phoenix.PubSub

  @typing_text "The quick brown fox jumps over the lazy dog."

  def mount(%{"room_id" => room_id}, _session, socket) do
    # Subscribe to room updates
    PubSub.subscribe(Typeracer.PubSub, "room:#{room_id}")
    
    # Generate user ID for this session
    user_id = generate_user_id()
    
    # Get the shareable URL dynamically
    shareable_url = get_shareable_url(socket, room_id)
    
    socket = 
      socket
      |> assign(:room_id, room_id)
      |> assign(:user_id, user_id)
      |> assign(:shareable_url, shareable_url)
      |> assign(:typing_text, @typing_text)
      |> assign(:user_input, "")
      |> assign(:current_position, 0)
      |> assign(:mistakes, 0)
      |> assign(:finished, false)
      |> assign(:players, %{})  # Only other players, not current user
      |> assign(:start_time, nil)
      |> assign(:wpm, 0)
    
    # Broadcast that user joined
    broadcast_user_joined(room_id, user_id)
    
    {:ok, socket}
  end

  def handle_event("typing", %{"value" => input}, socket) do
    %{
      typing_text: text,
      room_id: room_id,
      user_id: user_id,
      start_time: start_time
    } = socket.assigns
    
    # Start timer on first keystroke
    start_time = start_time || System.system_time(:millisecond)
    
    # Calculate position and mistakes
    {position, mistakes} = calculate_progress(input, text)
    finished = position >= String.length(text)
    
    # Calculate WPM
    wpm = calculate_wpm(input, start_time)
    
    # Only broadcast progress to OTHER players (not yourself)
    broadcast_progress(room_id, user_id, position, mistakes, wpm, finished)
    
    socket = 
      socket
      |> assign(:user_input, input)
      |> assign(:current_position, position)
      |> assign(:mistakes, mistakes)
      |> assign(:finished, finished)
      |> assign(:start_time, start_time)
      |> assign(:wpm, wpm)
    
    {:noreply, socket}
  end

  def handle_event("reset_race", _params, socket) do
    %{room_id: room_id, user_id: user_id} = socket.assigns
    
    # Broadcast reset to other players
    broadcast_reset(room_id, user_id)
    
    socket = 
      socket
      |> assign(:user_input, "")
      |> assign(:current_position, 0)
      |> assign(:mistakes, 0)
      |> assign(:finished, false)
      |> assign(:start_time, nil)
      |> assign(:wpm, 0)
    
    {:noreply, socket}
  end

  # Handle incoming broadcasts from OTHER players only
  def handle_info({:user_progress, user_id, position, mistakes, wpm, finished}, socket) do
    # Only update if it's NOT the current user
    if user_id != socket.assigns.user_id do
      players = Map.put(socket.assigns.players, user_id, %{
        position: position,
        mistakes: mistakes,
        wpm: wpm,
        finished: finished
      })
      
      {:noreply, assign(socket, :players, players)}
    else
      # Ignore broadcasts from self
      {:noreply, socket}
    end
  end

  def handle_info({:user_joined, user_id}, socket) do
    # Only add OTHER users to players list, not yourself
    if user_id != socket.assigns.user_id do
      players = Map.put(socket.assigns.players, user_id, %{
        position: 0,
        mistakes: 0,
        wpm: 0,
        finished: false
      })
      {:noreply, assign(socket, :players, players)}
    else
      # Don't add yourself to the players list
      {:noreply, socket}
    end
  end

  def handle_info({:user_reset, user_id}, socket) do
    # Only handle reset from OTHER users
    if user_id != socket.assigns.user_id do
      players = Map.put(socket.assigns.players, user_id, %{
        position: 0,
        mistakes: 0,
        wpm: 0,
        finished: false
      })
      {:noreply, assign(socket, :players, players)}
    else
      # Ignore reset broadcasts from self
      {:noreply, socket}
    end
  end

  # Handle user disconnect (optional enhancement)
  def handle_info({:user_left, user_id}, socket) do
    if user_id != socket.assigns.user_id do
      players = Map.delete(socket.assigns.players, user_id)
      {:noreply, assign(socket, :players, players)}
    else
      {:noreply, socket}
    end
  end

  # Helper functions
  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end

  # Get shareable URL dynamically based on current request
  defp get_shareable_url(socket, room_id) do
    # Try to get the host from the current request
    case get_connect_info(socket, :uri) do
      %URI{scheme: scheme, host: host, port: port} when not is_nil(host) ->
        port_part = if (scheme == "https" and port == 443) or (scheme == "http" and port == 80) do
          ""
        else
          ":#{port}"
        end
        "#{scheme}://#{host}#{port_part}/race/room/#{room_id}"
      _ ->
        # Fallback to endpoint URL
        "#{TyperacerWeb.Endpoint.url()}/race/room/#{room_id}"
    end
  end

  defp calculate_progress(input, text) do
    input_chars = String.graphemes(input)
    text_chars = String.graphemes(text)
    
    {position, mistakes} = 
      Enum.zip(input_chars, text_chars)
      |> Enum.with_index()
      |> Enum.reduce({0, 0}, fn {{input_char, text_char}, index}, {pos, mistakes} ->
        if input_char == text_char do
          {index + 1, mistakes}
        else
          {pos, mistakes + 1}
        end
      end)
    
    {position, mistakes}
  end

  defp calculate_wpm(input, start_time) do
    if start_time do
      time_elapsed = (System.system_time(:millisecond) - start_time) / 1000 / 60 # minutes
      if time_elapsed > 0 do
        words = String.length(String.trim(input)) / 5 # average word length
        round(words / time_elapsed)
      else
        0
      end
    else
      0
    end
  end

  defp broadcast_progress(room_id, user_id, position, mistakes, wpm, finished) do
    PubSub.broadcast(
      Typeracer.PubSub,
      "room:#{room_id}",
      {:user_progress, user_id, position, mistakes, wpm, finished}
    )
  end

  defp broadcast_user_joined(room_id, user_id) do
    PubSub.broadcast(
      Typeracer.PubSub,
      "room:#{room_id}",
      {:user_joined, user_id}
    )
  end

  defp broadcast_reset(room_id, user_id) do
    PubSub.broadcast(
      Typeracer.PubSub,
      "room:#{room_id}",
      {:user_reset, user_id}
    )
  end

  # Optional: Add this to handle when users leave (call this in terminate/2)
  defp broadcast_user_left(room_id, user_id) do
    PubSub.broadcast(
      Typeracer.PubSub,
      "room:#{room_id}",
      {:user_left, user_id}
    )
  end

  # Optional: Handle cleanup when user disconnects
  def terminate(_reason, socket) do
    if socket.assigns[:room_id] && socket.assigns[:user_id] do
      broadcast_user_left(socket.assigns.room_id, socket.assigns.user_id)
    end
    :ok
  end
end