defmodule BetZone.UserHistories do
  import Ecto.Query
  alias BetZone.Repo
  alias BetZone.UserHistories.UserHistory

  def list_user_histories(user_id) do
    UserHistory
    |> where([h], h.user_id == ^user_id)
    |> order_by([h], [desc: h.inserted_at])
    |> Repo.all()
  end

  def create_user_history(attrs \\ %{}) do
    %UserHistory{}
    |> UserHistory.changeset(attrs)
    |> Repo.insert()
  end
end
