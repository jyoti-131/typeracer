defmodule Typeracer.RaceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Typeracer.Race` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{

      })
      |> Typeracer.Race.create_game()

    game
  end
end
