defmodule BetZone.Sports do
  @moduledoc """
  The Sports context.
  """

  import Ecto.Query, warn: false
  alias BetZone.Repo
  alias BetZone.Sports.Sport

  @doc """
  Returns the list of sports.
  """
  def list_sports do
    Repo.all(Sport)
  end

  @doc """
  Returns the list of active sports.
  """
  def list_active_sports do
    from(s in Sport, where: s.active == true)
    |> Repo.all()
  end

  @doc """
  Gets a single sport.
  """
  def get_sport!(id), do: Repo.get!(Sport, id)

  @doc """
  Creates a sport.
  """
  def create_sport(attrs \\ %{}) do
    %Sport{}
    |> Sport.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a sport.
  """
  def update_sport(%Sport{} = sport, attrs) do
    sport
    |> Sport.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sport.
  """
  def delete_sport(%Sport{} = sport) do
    Repo.delete(sport)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sport changes.
  """
  def change_sport(%Sport{} = sport, attrs \\ %{}) do
    Sport.changeset(sport, attrs)
  end
end
