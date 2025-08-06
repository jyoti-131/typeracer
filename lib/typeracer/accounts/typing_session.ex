defmodule Typeracer.Accounts.TypingSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "typing_sessions" do
    field :difficulty, :string
    field :text_content, :string
    field :wpm, :integer
    field :accuracy, :float
    field :mistakes_count, :integer, default: 0
    field :total_keystrokes, :integer, default: 0
    field :time_taken, :integer
    field :completed_at, :utc_datetime

    belongs_to :user_profile, Typeracer.Accounts.UserProfile

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:difficulty, :text_content, :wpm, :accuracy, :mistakes_count, 
                    :total_keystrokes, :time_taken, :completed_at, :user_profile_id])
    |> validate_required([:difficulty, :wpm, :accuracy, :user_profile_id])
    |> validate_inclusion(:difficulty, ["beginner", "intermediate", "advanced"])
    |> validate_number(:wpm, greater_than_or_equal_to: 0)
    |> validate_number(:accuracy, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end