defmodule Typeracer.Accounts.DailyStat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "daily_stats" do
    field :practice_date, :date
    field :sessions_count, :integer, default: 0
    field :total_time, :integer, default: 0
    field :average_wpm, :float, default: 0.0
    field :average_accuracy, :float, default: 0.0
    field :best_wpm, :integer, default: 0
    field :total_keystrokes, :integer, default: 0
    field :total_mistakes, :integer, default: 0

    belongs_to :user_profile, Typeracer.Accounts.UserProfile

    timestamps()
  end

  def changeset(daily_stat, attrs) do
    daily_stat
    |> cast(attrs, [:practice_date, :sessions_count, :total_time, :average_wpm, 
                    :average_accuracy, :best_wpm, :total_keystrokes, :total_mistakes,
                    :user_profile_id])
    |> validate_required([:practice_date, :user_profile_id])
    |> unique_constraint([:user_profile_id, :practice_date])
  end
end