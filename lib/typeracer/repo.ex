defmodule Typeracer.Repo do
  use Ecto.Repo,
    otp_app: :typeracer,
    adapter: Ecto.Adapters.Postgres
end
