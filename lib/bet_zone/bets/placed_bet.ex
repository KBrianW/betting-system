defmodule BetZone.Bets.PlacedBet do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "placed_bets" do
    field :total_odds, :decimal
    field :stake_amount, :decimal
    field :potential_win, :decimal
    field :status, :string, default: "pending"  # pending, won, lost, cancelled
    field :settled_at, :utc_datetime
    belongs_to :user, BetZone.Accounts.User
    has_many :selections, BetZone.Bets.BetSelection

    timestamps(type: :utc_datetime)
  end

  def changeset(placed_bet, attrs) do
    placed_bet
    |> cast(attrs, [:total_odds, :stake_amount, :potential_win, :status, :settled_at, :user_id])
    |> validate_required([:total_odds, :stake_amount, :potential_win, :status, :user_id])
    |> validate_number(:stake_amount, greater_than: 0)
    |> validate_number(:total_odds, greater_than: 1)
    |> validate_inclusion(:status, ["pending", "won", "lost", "cancelled"])
    |> foreign_key_constraint(:user_id)
    |> cast_assoc(:selections)
  end

  def by_user(query \\ __MODULE__, user_id) do
    where(query, [b], b.user_id == ^user_id)
  end

  def with_selections(query \\ __MODULE__) do
    preload(query, :selections)
  end

  def pending(query \\ __MODULE__) do
    where(query, [b], b.status == "pending")
  end
end
