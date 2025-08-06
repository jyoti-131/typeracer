defmodule Typeracer.RaceTest do
  use Typeracer.DataCase

  alias Typeracer.Race

  describe "races" do
    alias Typeracer.Race.Game

    import Typeracer.RaceFixtures

    @invalid_attrs %{}

    test "list_races/0 returns all races" do
      game = game_fixture()
      assert Race.list_races() == [game]
    end

    test "get_game!/1 returns the game with given id" do
      game = game_fixture()
      assert Race.get_game!(game.id) == game
    end

    test "create_game/1 with valid data creates a game" do
      valid_attrs = %{}

      assert {:ok, %Game{} = game} = Race.create_game(valid_attrs)
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Race.create_game(@invalid_attrs)
    end

    test "update_game/2 with valid data updates the game" do
      game = game_fixture()
      update_attrs = %{}

      assert {:ok, %Game{} = game} = Race.update_game(game, update_attrs)
    end

    test "update_game/2 with invalid data returns error changeset" do
      game = game_fixture()
      assert {:error, %Ecto.Changeset{}} = Race.update_game(game, @invalid_attrs)
      assert game == Race.get_game!(game.id)
    end

    test "delete_game/1 deletes the game" do
      game = game_fixture()
      assert {:ok, %Game{}} = Race.delete_game(game)
      assert_raise Ecto.NoResultsError, fn -> Race.get_game!(game.id) end
    end

    test "change_game/1 returns a game changeset" do
      game = game_fixture()
      assert %Ecto.Changeset{} = Race.change_game(game)
    end
  end
end
