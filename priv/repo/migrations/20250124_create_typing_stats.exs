defmodule Typeracer.Repo.Migrations.CreateTypingStats do
  use Ecto.Migration

  def change do
    # User profiles table
    create table(:user_profiles) do
      add :user_id, :string, null: false
      add :username, :string
      add :total_tests, :integer, default: 0
      add :total_time_practiced, :integer, default: 0
      add :best_wpm, :integer, default: 0
      add :average_wpm, :float, default: 0.0
      add :best_accuracy, :float, default: 0.0
      add :average_accuracy, :float, default: 0.0
      add :total_keystrokes, :integer, default: 0
      add :total_mistakes, :integer, default: 0
      add :favorite_difficulty, :string, default: "intermediate"
      add :streak_days, :integer, default: 0
      add :last_practice_date, :date

      timestamps()
    end

    create unique_index(:user_profiles, [:user_id])

    # Individual typing sessions table
    create table(:typing_sessions) do
      add :user_profile_id, references(:user_profiles, on_delete: :delete_all), null: false
      add :difficulty, :string, null: false
      add :text_content, :text
      add :wpm, :integer, null: false
      add :accuracy, :float, null: false
      add :mistakes_count, :integer, default: 0
      add :total_keystrokes, :integer, default: 0
      add :time_taken, :integer
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:typing_sessions, [:user_profile_id])
    create index(:typing_sessions, [:completed_at])

    # Daily statistics
    create table(:daily_stats) do
      add :user_profile_id, references(:user_profiles, on_delete: :delete_all), null: false
      add :practice_date, :date, null: false
      add :sessions_count, :integer, default: 0
      add :total_time, :integer, default: 0
      add :average_wpm, :float, default: 0.0
      add :average_accuracy, :float, default: 0.0
      add :best_wpm, :integer, default: 0
      add :total_keystrokes, :integer, default: 0
      add :total_mistakes, :integer, default: 0

      timestamps()
    end

    create unique_index(:daily_stats, [:user_profile_id, :practice_date])

    # Character mistakes tracking
    create table(:character_mistakes) do
      add :user_profile_id, references(:user_profiles, on_delete: :delete_all), null: false
      add :character, :string, size: 1, null: false
      add :mistake_count, :integer, default: 1
      add :last_mistake_at, :utc_datetime

      timestamps()
    end

    create unique_index(:character_mistakes, [:user_profile_id, :character])
  end
end