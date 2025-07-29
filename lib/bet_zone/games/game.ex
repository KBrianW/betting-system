defmodule BetZone.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetZone.Sports.Sport
  alias BetZone.Teams.Team

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
    field :published, :boolean, default: true

    belongs_to :sport, Sport
    belongs_to :team_a, Team
    belongs_to :team_b, Team

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:scheduled_time, :odds_win, :odds_draw, :odds_loss, :status, :score_a, :score_b, :week, :cycle, :sport_id, :team_a_id, :team_b_id, :published])
    |> validate_required([:scheduled_time, :odds_win, :odds_draw, :odds_loss, :status, :week, :cycle, :sport_id, :team_a_id, :team_b_id])
    |> foreign_key_constraint(:sport_id)
    |> foreign_key_constraint(:team_a_id)
    |> foreign_key_constraint(:team_b_id)
    |> validate_different_teams()
  end

  defp validate_different_teams(changeset) do
    team_a_id = get_field(changeset, :team_a_id)
    team_b_id = get_field(changeset, :team_b_id)

    if team_a_id && team_b_id && team_a_id == team_b_id do
      add_error(changeset, :team_b_id, "must be different from team A")
    else
      changeset
    end
  end
end
