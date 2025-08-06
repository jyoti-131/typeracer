defmodule Typeracer.Accounts.UserProfile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_profiles" do
    field :user_id, :string
    field :username, :string
    field :total_tests, :integer, default: 0
    field :total_time_practiced, :integer, default: 0
    field :best_wpm, :integer, default: 0
    field :average_wpm, :float, default: 0.0
    field :best_accuracy, :float, default: 0.0
    field :average_accuracy, :float, default: 0.0
    field :total_keystrokes, :integer, default: 0
    field :total_mistakes, :integer, default: 0
    field :favorite_difficulty, :string, default: "intermediate"
    field :streak_days, :integer, default: 0
    field :last_practice_date, :date

    has_many :typing_sessions, Typeracer.Accounts.TypingSession
    has_many :daily_stats, Typeracer.Accounts.DailyStat
    has_many :character_mistakes, Typeracer.Accounts.CharacterMistake

    timestamps()
  end

  def changeset(user_profile, attrs) do
    user_profile
    |> cast(attrs, [:user_id, :username, :total_tests, :total_time_practiced, 
                    :best_wpm, :average_wpm, :best_accuracy, :average_accuracy,
                    :total_keystrokes, :total_mistakes, :favorite_difficulty, 
                    :streak_days, :last_practice_date])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end