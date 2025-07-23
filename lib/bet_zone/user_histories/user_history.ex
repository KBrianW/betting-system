defmodule BetZone.UserHistories.UserHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_histories" do
    field :info, :string
    field :type, :string
    field :ref_id, :integer
    belongs_to :user, BetZone.Accounts.User

    timestamps()
  end

  def changeset(user_history, attrs) do
    user_history
    |> cast(attrs, [:user_id, :info, :type, :ref_id])
    |> validate_required([:user_id, :info, :type])
  end
end
