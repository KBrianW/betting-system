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
    Repo.all(Team)
  end
end
