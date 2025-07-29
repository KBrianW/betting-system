defmodule BetZone.Teams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    belongs_to :sport, BetZone.Sports.Sport
    timestamps()
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :sport_id])
    |> validate_required([:name, :sport_id])
    |> unique_constraint(:name)
  end
end
