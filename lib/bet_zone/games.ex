defmodule BetZone.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias BetZone.Repo
  alias BetZone.Games.Game

  @doc """
  Returns the list of games with preloaded associations.
  """
  def list_games do
    Repo.all(Game) |> Repo.preload([:sport, :team_a, :team_b])
  end

  @doc """
  Returns the list of games for a specific sport.
  """
  def list_games_by_sport(sport_id) do
    from(g in Game, where: g.sport_id == ^sport_id)
    |> Repo.all()
    |> Repo.preload([:sport, :team_a, :team_b])
  end

  @doc """
  Returns the list of games by week and cycle.
  """
  def list_games_by_week_and_cycle(week, cycle) do
    from(g in Game, where: g.week == ^week and g.cycle == ^cycle)
    |> Repo.all()
    |> Repo.preload([:sport, :team_a, :team_b])
  end

  @doc """
  Returns the list of games by cycle.
  """
  def list_games_by_cycle(cycle) do
    from(g in Game, where: g.cycle == ^cycle)
    |> Repo.all()
    |> Repo.preload([:sport, :team_a, :team_b])
  end

  @doc """
  Gets a single game with preloaded associations.
  """
  def get_game!(id) do
    Repo.get!(Game, id) |> Repo.preload([:sport, :team_a, :team_b])
  end

  @doc """
  Creates a game.
  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.
  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.
  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Deletes all games by cycle.
  """
  def delete_games_by_cycle(cycle) do
    from(g in Game, where: g.cycle == ^cycle)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.
  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  @doc """
  Updates game status (scheduled, ongoing, completed, postponed, cancelled).
  """
  def update_game_status(%Game{} = game, status) when status in ["scheduled", "ongoing", "completed", "postponed", "cancelled"] do
    update_game(game, %{status: status})
  end

  @doc """
  Updates game scores.
  """
  def update_game_scores(%Game{} = game, score_a, score_b) do
    update_game(game, %{score_a: score_a, score_b: score_b})
  end
end
