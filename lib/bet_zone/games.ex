defmodule BetZone.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias BetZone.Repo
  alias BetZone.Games.Game

  def list_games do
    Repo.all(Game)
  end

  def list_games_by_week_and_cycle(week, cycle) do
    Repo.all(from g in Game, where: g.week == ^week and g.cycle == ^cycle)
  end

  def list_games_by_cycle(cycle) do
    Repo.all(from g in Game, where: g.cycle == ^cycle)
  end

  def get_game!(id), do: Repo.get!(Game, id)

  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  def delete_games_by_cycle(cycle) do
    from(g in Game, where: g.cycle == ^cycle)
    |> Repo.delete_all()
  end
end
