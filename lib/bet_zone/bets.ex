defmodule BetZone.Bets do
  import Ecto.Query
  alias BetZone.Repo
  alias BetZone.Bets.PlacedBet
  alias BetZone.Bets.BetSelection

  # Return all placed bets for a user (including cancelled ones for history)
  def list_placed_bets(user_id, opts \\ []) do
    query =
      from b in PlacedBet,
        where: b.user_id == ^user_id,
        order_by: [desc: b.inserted_at]

    # Optional status filter
    query =
      case Keyword.get(opts, :statuses) do
        nil -> query
        statuses -> from b in query, where: b.status in ^statuses
      end

    # Optional exclude_drafts filter
    query =
      if Keyword.get(opts, :exclude_drafts, false) do
        from b in query, where: not (b.status == "pending" and b.potential_win == 0)
      else
        query
      end

    Repo.all(query)
  end


  def preload_selections(placed_bets) when is_list(placed_bets) do
    Repo.preload(placed_bets, [selections: [:game]])
  end

  def preload_selections(%PlacedBet{} = placed_bet) do
    Repo.preload(placed_bet, [selections: [:game]])
  end

  # Place a bet: move from draft to placed_bets with status "active"
  def place_bet_from_draft(user_id) do
    drafts = Repo.all(from d in "draft_bets", where: d.user_id == ^user_id and d.status == "pending")
    if drafts == [] do
      {:error, :no_draft}
    else
      attrs = %{
        user_id: user_id,
        total_odds: Enum.reduce(drafts, 1, fn d, acc -> acc * d.odds end),
        stake_amount: Enum.at(drafts, 0).stake, # Assuming same stake for all
        potential_win: Enum.reduce(drafts, 1, fn d, acc -> acc * d.odds end) * Enum.at(drafts, 0).stake,
        status: "active"
      }
      bet_slip = Enum.map(drafts, fn d -> %{game_id: d.game_id, game_desc: d.game_desc, type: d.type, odds: d.odds} end)
      result = create_placed_bet(attrs, bet_slip)
      # Mark drafts as cleared
      clear_draft_bets(user_id)
      result
    end
  end

  def create_placed_bet(attrs, bet_slip) do
    Repo.transaction(fn ->
      placed_bet_changeset = PlacedBet.changeset(%PlacedBet{}, attrs)

      case Repo.insert(placed_bet_changeset) do
        {:ok, placed_bet} ->
          selections =
            Enum.map(bet_slip, fn bet ->
              %{
                placed_bet_id: placed_bet.id,
                game_id: bet.game_id,
                game_desc: bet.game_desc || "",
                selection_type: String.downcase(bet.selection_type || bet.type),
                odds: bet.odds,
                result: "pending",
                inserted_at: Timex.now() |> DateTime.truncate(:second),
                updated_at: Timex.now() |> DateTime.truncate(:second)
              }
            end)

          case Repo.insert_all(BetSelection, selections, returning: true) do
            {count, inserted_selections} when count > 0 ->
              %{placed_bet | selections: inserted_selections}

            _ ->
              IO.inspect(selections, label: "❌ Selections insert failed")
              Repo.rollback("Failed to insert selections")
          end

          {:error, changeset} ->
            IO.inspect(changeset, label: "❌ Full PlacedBet changeset")
            Repo.rollback(changeset)
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

  def get_bet_with_selections(id) do
    PlacedBet
    |> where([b], b.id == ^id)
    |> PlacedBet.with_selections()
    |> Repo.one()
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

  def delete_bet(%PlacedBet{} = placed_bet) do
    Repo.delete(placed_bet)
  end

  def cancel_bet(%PlacedBet{} = placed_bet) do
    Repo.transaction(fn ->
      changeset =
        placed_bet
        |> Ecto.Changeset.change(
          status: "cancelled",
          result: "cancelled",
          cancelled_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      updated_bet = Repo.update!(changeset)

      # Only create refund transaction for active bets (where money was actually taken)
      # Pending bets never had money deducted, so no refund is needed
      if placed_bet.status == "active" do
        BetZone.Transactions.create_refund_transaction(
          BetZone.Accounts.get_user!(placed_bet.user_id),
          placed_bet,
          "bet_cancel"
        )
      end

      # Return the updated bet
      updated_bet
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

    # Determine bet status based on selection results
    selection_results = Enum.map(updated_selections, & &1.result)

    new_status = cond do
      # If any selection is lost, the entire bet is lost (immediate loss)
      Enum.any?(selection_results, &(&1 == "lost")) ->
        "lost"

      # If all selections are won, the bet is won
      Enum.all?(selection_results, &(&1 == "won")) ->
        "won"

      # If there are pending selections and at least one game is ongoing, bet is active
      Enum.any?(selection_results, &(&1 == "pending")) &&
      Enum.any?(updated_selections, fn sel -> sel.game.status == "ongoing" end) ->
        "active"

      # If all games are upcoming (not started), keep as pending for draft bets
      # or active for placed bets
      Enum.all?(selection_results, &(&1 == "pending")) &&
      Enum.all?(updated_selections, fn sel -> sel.game.status == "upcoming" end) ->
        if placed_bet.status == "pending", do: "pending", else: "active"

      # Default to active for placed bets
      true ->
        if placed_bet.status == "pending", do: "pending", else: "active"
    end

    # Update bet status and handle transactions if status changed
    if placed_bet.status != new_status do
      # Prepare changeset attributes based on new status
      changeset_attrs = case new_status do
        status when status in ["pending", "active"] ->
          # For pending/active status, result must be nil
          %{status: new_status, result: nil}
        "completed" ->
          # For completed status, determine result based on selections
          final_result = cond do
            Enum.any?(Enum.map(updated_selections, & &1.result), &(&1 == "lost")) -> "lost"
            Enum.all?(Enum.map(updated_selections, & &1.result), &(&1 == "won")) -> "won"
            true -> nil  # This shouldn't happen for completed bets
          end
          %{status: new_status, result: final_result, settled_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        "cancelled" ->
          # For cancelled status, result should be "cancelled"
          %{status: new_status, result: "cancelled", cancelled_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      end

      updated_bet = placed_bet
      |> PlacedBet.changeset(changeset_attrs)
      |> Repo.update!()

      # Handle transactions for completed bets
      case new_status do
        "lost" ->
          # Create loss transaction (no money returned)
          BetZone.Transactions.create_bet_transaction(
            BetZone.Accounts.get_user!(placed_bet.user_id),
            placed_bet,
            "bet_loss"
          )
        "won" ->
          # Credit wallet with winnings
          BetZone.Transactions.create_bet_transaction(
            BetZone.Accounts.get_user!(placed_bet.user_id),
            placed_bet,
            "bet_win"
          )
        _ ->
          # No transaction needed for active/pending status
          :ok
      end

      updated_bet
    else
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

  def total_user_losses do
    from(b in PlacedBet, where: b.status == "lost", select: sum(b.stake_amount))
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total
    end
  end

  def total_income do
    from(b in PlacedBet, where: b.status in ["won", "lost"], select: sum(b.stake_amount))
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total
    end
  end

  def total_profit do
    total_income() - total_user_losses()
  end

  def list_user_bets(user_id) do
    PlacedBet
    |> PlacedBet.by_user(user_id)
    |> PlacedBet.with_selections()
    |> Repo.all()
  end
end
