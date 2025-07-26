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
      placed_bet = Repo.preload(placed_bet, :user)
      # 1. Update the bet status to "cancelled"
      changeset = Ecto.Changeset.change(placed_bet, status: "cancelled")
      updated_bet = Repo.update!(changeset)

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

  def list_user_cancelled_bets(user_id) do
    from(b in PlacedBet,
      where: b.user_id == ^user_id and b.status == "cancelled",
      order_by: [desc: b.inserted_at]
    )
    |> BetZone.Repo.all()
  end

  def list_user_completed_bets(user_id) do
    Repo.all(
      from b in PlacedBet,
        where: b.user_id == ^user_id and b.status in ["won", "lost"],
        preload: [:game]
    )
  end

  # Evaluate and update the status of a placed bet and its selections
  def evaluate_and_update_bet(%PlacedBet{} = placed_bet) do
    placed_bet = Repo.preload(placed_bet, selections: [:game], user: [])
    selections = placed_bet.selections

    # Evaluate each selection
    updated_selections = Enum.map(selections, fn sel ->
      game = sel.game
      cond do
        game.status == "completed" && !is_nil(game.score_a) && !is_nil(game.score_b) ->
          result =
            case sel.selection_type do
              "win" ->
                if game.score_a > game.score_b, do: "won", else: "lost"
              "draw" ->
                if game.score_a == game.score_b, do: "won", else: "lost"
              "loss" ->
                if game.score_a < game.score_b, do: "won", else: "lost"
            end
          if sel.result != result do
            sel
            |> BetSelection.changeset(%{result: result})
            |> Repo.update!()
          else
            sel
          end
        game.status == "ongoing" or game.status == "completed" ->
          # If game is ongoing or completed but no score, keep as pending
          if sel.result != "pending" do
            sel
            |> BetSelection.changeset(%{result: "pending"})
            |> Repo.update!()
          else
            sel
          end
        true ->
          sel
      end
    end)

    # Determine bet status
    selection_results = Enum.map(updated_selections, & &1.result)
    cond do
      Enum.any?(selection_results, &(&1 == "lost")) ->
        if placed_bet.status != "lost" do
          placed_bet
          |> PlacedBet.changeset(%{status: "lost"})
          |> Repo.update!()
          # Create loss transaction if needed
          BetZone.Transactions.create_bet_transaction(placed_bet.user, placed_bet, "bet_loss")
        end
      Enum.all?(selection_results, &(&1 == "won")) ->
        if placed_bet.status != "won" do
          placed_bet
          |> PlacedBet.changeset(%{status: "won"})
          |> Repo.update!()
          # Credit wallet
          BetZone.Transactions.create_bet_transaction(placed_bet.user, placed_bet, "bet_win")
        end
      Enum.all?(selection_results, &(&1 == "pending")) ->
        if placed_bet.status != "pending" do
          placed_bet
          |> PlacedBet.changeset(%{status: "pending"})
          |> Repo.update!()
        end
      Enum.any?(selection_results, &(&1 == "pending")) && Enum.any?(updated_selections, fn sel -> sel.game.status == "ongoing" end) ->
        if placed_bet.status != "active" do
          placed_bet
          |> PlacedBet.changeset(%{status: "active"})
          |> Repo.update!()
        end
      true ->
        placed_bet
    end
    # Return the updated bet (reloaded)
    Repo.get!(PlacedBet, placed_bet.id) |> Repo.preload([selections: [:game], user: []])
  end

  # Evaluate and update all bets for a user
  def evaluate_and_update_user_bets(user_id) do
    list_placed_bets(user_id)
    |> preload_selections()
    |> Enum.map(&evaluate_and_update_bet/1)
  end
end
