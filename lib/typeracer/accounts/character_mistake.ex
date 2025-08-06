defmodule Typeracer.Accounts.CharacterMistake do
  use Ecto.Schema
  import Ecto.Changeset

  schema "character_mistakes" do
    field :character, :string
    field :mistake_count, :integer, default: 1
    field :last_mistake_at, :utc_datetime

    belongs_to :user_profile, Typeracer.Accounts.UserProfile

    timestamps()
  end

  def changeset(character_mistake, attrs) do
    character_mistake
    |> cast(attrs, [:character, :mistake_count, :last_mistake_at, :user_profile_id])
    |> validate_required([:character, :user_profile_id])
    |> validate_length(:character, is: 1)
    |> unique_constraint([:user_profile_id, :character])
  end
end