defmodule BetZone.Teams do
  @moduledoc """
  The Teams context.
  """

  import Ecto.Query, warn: false
  alias BetZone.Repo
  alias BetZone.Teams.Team

  @doc """
  Returns the list of teams.
  """
  def list_teams do
    Repo.all(Team) |> Repo.preload(:sport)
  end

  @doc """
  Returns the list of teams for a specific sport.
  """
  def list_teams_by_sport(sport_id) do
    from(t in Team, where: t.sport_id == ^sport_id)
    |> Repo.all()
    |> Repo.preload(:sport)
  end

  @doc """
  Gets a single team.
  """
  def get_team!(id), do: Repo.get!(Team, id) |> Repo.preload(:sport)

  @doc """
  Creates a team.
  """
  def create_team(attrs \\ %{}) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a team.
  """
  def update_team(%Team{} = team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a team.
  """
  def delete_team(%Team{} = team) do
    Repo.delete(team)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.
  """
  def change_team(%Team{} = team, attrs \\ %{}) do
    Team.changeset(team, attrs)
  end
end
