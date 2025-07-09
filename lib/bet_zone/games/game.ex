defmodule BetZone.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :status, :string
    field :cycle, :integer
    field :week, :integer
    field :scheduled_time, :utc_datetime
    field :odds_win, :float
    field :odds_draw, :float
    field :odds_loss, :float
    field :score_a, :integer
    field :score_b, :integer
    field :team_a_id, :id
    field :team_b_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:scheduled_time, :odds_win, :odds_draw, :odds_loss, :status, :score_a, :score_b, :week, :cycle, :team_a_id, :team_b_id])
    |> validate_required([:scheduled_time, :odds_win, :odds_draw, :odds_loss, :status, :week, :cycle, :team_a_id, :team_b_id])
  end
end
