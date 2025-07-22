defmodule BetZone.Bets.DraftBet do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "draft_bets" do
    field :game_id, :integer
    field :game_desc, :string
    field :type, :string
    field :odds, :float
    field :stake, :integer, default: 1
    belongs_to :user, BetZone.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(draft_bet, attrs) do
    draft_bet
    |> cast(attrs, [:game_id, :game_desc, :type, :odds, :stake, :user_id])
    |> validate_required([:game_id, :game_desc, :type, :odds, :user_id])
    |> validate_number(:stake, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end

  def by_user(query \\ __MODULE__, user_id) do
    where(query, [d], d.user_id == ^user_id)
  end
end
