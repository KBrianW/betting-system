defmodule BetZone.Bets.PlacedBet do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "placed_bets" do
    field :total_odds, :decimal
    field :stake_amount, :decimal
    field :potential_win, :decimal
    field :status, :string, default: "pending"  # pending, won, lost, cancelled
    field :result, :string
    field :settled_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    belongs_to :user, BetZone.Accounts.User
    has_many :selections, BetZone.Bets.BetSelection

    timestamps(type: :utc_datetime)
  end

  def changeset(placed_bet, attrs) do
    placed_bet
    |> cast(attrs, [
      :total_odds,
      :stake_amount,
      :potential_win,
      :status,
      :result,
      :settled_at,
      :cancelled_at,
      :user_id
    ])
    |> validate_required([
      :total_odds,
      :stake_amount,
      :potential_win,
      :status,
      :user_id
    ])
    |> validate_number(:stake_amount, greater_than: 0)
    |> validate_number(:total_odds, greater_than: 1)
    |> validate_inclusion(:status, ["pending", "active", "completed", "cancelled"])
    |> validate_inclusion(:result, ["won", "lost", "cancelled"])
    |> validate_mutually_exclusive_status()
    |> foreign_key_constraint(:user_id)
    |> cast_assoc(:selections)
  end

  defp validate_mutually_exclusive_status(changeset) do
    status = get_field(changeset, :status)
    result = get_field(changeset, :result)

    cond do
      status == "cancelled" and result != "cancelled" ->
        add_error(changeset, :result, "must be 'cancelled' when status is 'cancelled'")

      status == "completed" and is_nil(result) ->
        add_error(changeset, :result, "must be set when status is 'completed'")

      status in ["pending", "active"] and not is_nil(result) ->
        add_error(changeset, :result, "must be nil when status is pending or active")

      true ->
        changeset
    end
  end
  def by_user(query \\ __MODULE__, user_id) do
    where(query, [b], b.user_id == ^user_id)
  end

  def with_selections(query \\ __MODULE__) do
    preload(query, [selections: :game])  # Preload games with selections for better performance
  end

  # Status-specific queries
  def pending(query \\ __MODULE__) do
    where(query, [b], b.status == "pending")
  end

  def active(query \\ __MODULE__) do
    where(query, [b], b.status == "active")
  end

  def completed(query \\ __MODULE__) do
    where(query, [b], b.status == "completed")
  end

  def cancelled(query \\ __MODULE__) do
    where(query, [b], b.status == "cancelled")
  end

  # Result-specific queries (for history)
  def won(query \\ __MODULE__) do
    where(query, [b], b.result == "won")
  end

  def lost(query \\ __MODULE__) do
    where(query, [b], b.result == "lost")
  end

  # Combined queries for common use cases
  def active_or_pending(query \\ __MODULE__) do
    where(query, [b], b.status in ["pending", "active"])
  end

  def settled(query \\ __MODULE__) do
    where(query, [b], b.status == "completed" or b.status == "cancelled")
  end

  # For checking cancellable bets
  def cancellable(query \\ __MODULE__) do
    pending(query)  # Only pending bets can be cancelled in your workflow
  end
end
