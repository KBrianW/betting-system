defmodule BetZone.Bets.BetSelection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bet_selections" do
    field :selection_type, :string  # win, draw, loss
    field :odds, :decimal
    field :result, :string  # won, lost, pending, cancelled
    belongs_to :placed_bet, BetZone.Bets.PlacedBet
    belongs_to :game, BetZone.Games.Game
    field :game_desc, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(bet_selection, attrs) do
    bet_selection
    |> cast(attrs, [:selection_type, :odds, :result, :placed_bet_id, :game_id])
    |> validate_required([:selection_type, :odds, :placed_bet_id, :game_id])
    |> validate_number(:odds, greater_than: 1)
    |> validate_inclusion(:selection_type, ["win", "draw", "loss"])
    |> validate_inclusion(:result, ["won", "lost", "pending", "cancelled"])
    |> foreign_key_constraint(:placed_bet_id)
    |> foreign_key_constraint(:game_id)
  end
end
