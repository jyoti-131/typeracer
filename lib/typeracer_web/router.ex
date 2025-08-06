defmodule TyperacerWeb.Router do
  use TyperacerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TyperacerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Add session management to ensure user_id persists
    plug :ensure_user_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Plug to ensure user_id exists in session
  defp ensure_user_session(conn, _opts) do
    case get_session(conn, "user_id") do
      nil ->
        # Generate new user_id if none exists
        user_id = "user_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16())
        put_session(conn, "user_id", user_id)
      _existing ->
        # Keep existing user_id
        conn
    end
  end

  scope "/", TyperacerWeb do
    pipe_through :browser

    # Simple routes without additional session handling
    # The session management is handled by the ensure_user_session plug above
    live "/", RaceLive.Index, :index
    live "/profile", ProfileLive.Index, :index
    
    # Multiplayer typing race route
    live "/race/room/:room_id", GameLive.RaceRoomLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", TyperacerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:typeracer, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TyperacerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end