defmodule BetZone.Sports.Sport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sports" do
    field :name, :string
    field :emoji, :string
    field :active, :boolean, default: true

    has_many :teams, BetZone.Teams.Team

    timestamps()
  end

  @doc false
  def changeset(sport, attrs) do
    sport
    |> cast(attrs, [:name, :emoji, :active])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
