defmodule BetZone.Bets do
  import Ecto.Query
  alias BetZone.Repo
  alias BetZone.Bets.PlacedBet
  alias BetZone.Bets.BetSelection
  alias BetZone.Games.Game

  def list_placed_bets(user_id) do
    PlacedBet
    |> where([b], b.user_id == ^user_id)
    |> order_by([b], [desc: b.inserted_at])
    |> Repo.all()
  end

  def preload_selections(placed_bets) when is_list(placed_bets) do
    Repo.preload(placed_bets, [selections: [:game]])
  end

  def preload_selections(%PlacedBet{} = placed_bet) do
    Repo.preload(placed_bet, [selections: [:game]])
  end

  def create_placed_bet(attrs, bet_slip) do
    Repo.transaction(fn ->
      # Create the placed bet
      placed_bet_changeset = PlacedBet.changeset(%PlacedBet{}, attrs)

      with {:ok, placed_bet} <- Repo.insert(placed_bet_changeset) do
        # Create selections for each bet in the slip
        selections =
          Enum.map(bet_slip, fn bet ->
            %{
              placed_bet_id: placed_bet.id,
              game_id: bet.game_id,
              game_desc: bet.game_desc,
              selection_type: String.downcase(bet.type),
              odds: bet.odds,
              result: "pending",
              inserted_at: Timex.now() |> DateTime.truncate(:second),
              updated_at: Timex.now() |> DateTime.truncate(:second)


            }
          end)

        {_count, selections} =
          Repo.insert_all(BetSelection, selections,
            returning: true
          )

        %{placed_bet | selections: selections}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def save_bet_slip(user_id, bet_slip) do
    # Delete existing draft bets
    delete_all_draft_bets(user_id)

    # Insert new draft bets
    drafts =
      Enum.map(bet_slip, fn bet ->
        %{
          user_id: user_id,
          game_id: bet.game_id,
          game_desc: bet.game_desc,
          type: bet.type,
          odds: bet.odds,
          stake: bet.stake,
          status: "pending",
          inserted_at: Timex.now() |> DateTime.truncate(:second),
          updated_at: Timex.now() |> DateTime.truncate(:second)
        }
      end)

    Repo.insert_all("draft_bets", drafts)
  end

  def list_draft_bets(user_id) do
    from(d in "draft_bets",
      where: d.user_id == ^user_id and d.status == "pending",
      select: %{
        game_id: d.game_id,
        game_desc: d.game_desc,
        type: d.type,
        odds: d.odds,
        stake: d.stake
      }
    )
    |> Repo.all()
  end

  def delete_all_draft_bets(user_id) do
    from(d in "draft_bets", where: d.user_id == ^user_id)
    |> Repo.delete_all()
  end

  def clear_draft_bets(user_id) do
    from(d in "draft_bets", where: d.user_id == ^user_id)
    |> Repo.update_all(set: [status: "cleared"])
  end

  def get_placed_bet!(id), do: Repo.get!(PlacedBet, id)

  def update_placed_bet(%PlacedBet{} = placed_bet, attrs) do
    placed_bet
    |> PlacedBet.changeset(attrs)
    |> Repo.update()
  end

  def delete_placed_bet(%PlacedBet{} = placed_bet) do
    Repo.delete(placed_bet)
  end

  def cancel_bet(%PlacedBet{} = placed_bet) do
    Repo.transaction(fn ->
      # 1. Update the bet status to "cancelled"
      changeset = Ecto.Changeset.change(placed_bet, status: "cancelled")
      Repo.update!(changeset)

      # 2. Create a refund transaction
      BetZone.Transactions.create_refund_transaction(
        placed_bet.user,
        placed_bet,
        "bet_cancel"
      )

      # 3. Return the updated bet
      placed_bet
    end)
  end
end
