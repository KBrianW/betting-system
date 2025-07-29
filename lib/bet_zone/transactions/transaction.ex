defmodule BetZone.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "transactions" do
    field :amount, :decimal
    field :type, :string  # deposit, withdrawal, bet_place, bet_win, bet_loss
    field :status, :string, default: "pending"  # pending, completed, failed
    field :reference, :string
    field :description, :string
    belongs_to :user, BetZone.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :type, :status, :reference, :description, :user_id])
    |> validate_required([:amount, :type, :status, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:type, ["deposit", "withdrawal", "bet_place", "bet_win", "bet_loss", "bet_cancel"])
    |> validate_inclusion(:status, ["pending", "completed", "failed"])
    |> foreign_key_constraint(:user_id)
  end

  def by_user(query \\ __MODULE__, user_id) do
    where(query, [t], t.user_id == ^user_id)
  end

  def deposits(query \\ __MODULE__) do
    where(query, [t], t.type == "deposit")
  end

  def completed(query \\ __MODULE__) do
    where(query, [t], t.status == "completed")
  end
end
