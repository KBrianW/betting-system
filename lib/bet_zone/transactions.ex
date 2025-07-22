defmodule BetZone.Transactions do
  import Ecto.Query
  alias BetZone.Repo
  alias BetZone.Transactions.Transaction
  alias BetZone.Accounts.User
  alias BetZone.Games

  def create_bet_transaction(user, bet, type) when type in ["bet_place", "bet_win", "bet_loss"] do
    description = case type do
      "bet_place" -> "Bet placed on #{format_bet_selections(bet)}"
      "bet_win" -> "Won bet on #{format_bet_selections(bet)}"
      "bet_loss" -> "Lost bet on #{format_bet_selections(bet)}"
    end

    amount = case type do
      "bet_place" -> bet.stake_amount
      "bet_win" -> bet.potential_win
      "bet_loss" -> bet.stake_amount
    end

    create_transaction(%{
      user_id: user.id,
      amount: amount,
      type: type,
      status: "completed",
      description: description
    })
  end

  def create_deposit(user, amount) do
    IO.inspect({:deposit_start, user_id: user.id, amount: amount})
    Repo.transaction(fn ->
      transaction_attrs = %{
        user_id: user.id,
        amount: amount,
        type: "deposit",
        status: "completed",
        description: "Wallet deposit"
      }

      with {:ok, transaction} <- create_transaction(transaction_attrs),
           {:ok, _user} <- update_user_wallet(user, Decimal.new(amount)) do
        IO.inspect({:deposit_success, user_id: user.id, amount: amount})
        transaction
      else
        {:error, changeset} ->
          IO.inspect({:deposit_error, changeset: changeset})
          Repo.rollback(changeset)
      end
    end)
  end

  def create_withdrawal(user, amount) do
    Repo.transaction(fn ->
      current_balance = get_user_balance(user.id)

      if Decimal.compare(current_balance, amount) == :lt do
        {:error, "Insufficient balance"}
      else
        transaction_attrs = %{
          user_id: user.id,
          amount: amount,
          type: "withdrawal",
          status: "completed",
          description: "Wallet withdrawal"
        }

        with {:ok, transaction} <- create_transaction(transaction_attrs),
             {:ok, _user} <- update_user_wallet(user, Decimal.negate(amount)) do
          transaction
        else
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end
    end)
  end

  def create_transaction(attrs \\ %{}) do
    changeset = Transaction.changeset(%Transaction{}, attrs)
    try do
      case Repo.insert(changeset) do
        {:ok, transaction} -> {:ok, transaction}
        {:error, changeset} ->
          IO.inspect(changeset.errors, label: "Transaction Insert Errors")
          {:error, changeset}
      end
    rescue
      e ->
        IO.inspect(e, label: "Transaction Insert Exception")
        {:error, e}
    end
  end

  def list_user_transactions(user_id) do
    Transaction
    |> Transaction.by_user(user_id)
    |> order_by([t], [desc: t.inserted_at])
    |> Repo.all()
  end

  def get_user_balance(user_id) do
    completed_transactions = from(t in Transaction,
      where: t.user_id == ^user_id and t.status == "completed",
      select: %{
        deposits: sum(fragment("CASE WHEN type = 'deposit' THEN amount ELSE 0 END")),
        withdrawals: sum(fragment("CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END")),
        bet_places: sum(fragment("CASE WHEN type = 'bet_place' THEN amount ELSE 0 END")),
        bet_wins: sum(fragment("CASE WHEN type = 'bet_win' THEN amount ELSE 0 END"))
      }
    ) |> Repo.one()

    case completed_transactions do
      nil -> Decimal.new(0)
      txns ->
        Decimal.add(
          Decimal.add(
            (txns.deposits || Decimal.new(0)),
            (txns.bet_wins || Decimal.new(0))
          ),
          Decimal.sub(
            Decimal.new(0),
            Decimal.add(
              (txns.withdrawals || Decimal.new(0)),
              (txns.bet_places || Decimal.new(0))
            )
          )
        )
    end
  end

  defp update_user_wallet(user, amount) do
    current_balance = get_user_balance(user.id)
    new_balance = Decimal.add(current_balance, amount)
    IO.inspect({:wallet_update, user_id: user.id, current_balance: current_balance, amount: amount, new_balance: new_balance})

    result =
      user
      |> Ecto.Changeset.change(wallet: new_balance)
      |> Repo.update()

    if match?({:ok, _}, result) do
      IO.inspect({:pubsub_broadcast, topic: "wallet:#{user.id}", new_balance: new_balance})
      Phoenix.PubSub.broadcast(BetZone.PubSub, "wallet:#{user.id}", {:wallet_updated, new_balance})
    end

    result
  end

  defp format_bet_selections(bet) do
    bet.selections
    |> Enum.map(fn selection ->
      game = Games.get_game!(selection.game_id)
      "#{game.home_team} vs #{game.away_team} (#{selection.selection_type})"
    end)
    |> Enum.join(", ")
  end
end
