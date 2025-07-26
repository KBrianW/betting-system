defmodule BetZoneWeb.DashboardLive do
  use BetZoneWeb, :live_view
  # Remove authentication requirement for dashboard
  # on_mount {BetZoneWeb.UserAuth, :ensure_authenticated}
  alias BetZone.Teams
  alias BetZone.Games
  alias BetZone.Bets
  alias Timex.Timex
  alias BetZone.Transactions
  alias BetZone.UserHistories

  @weeks 8
  @games_per_week 8
  @season_start ~D[2024-06-24]

  @impl true
  def mount(_params, session, socket) do
    current_user =
      if user_token = session["user_token"] do
        BetZone.Accounts.get_user_by_session_token(user_token)
      else
        nil
      end

    if is_nil(current_user) do
      {:ok, Phoenix.LiveView.redirect(socket, to: "/users/log_in")}
    else
      teams = Teams.list_teams()
      now = DateTime.utc_now()
      current_week = week_number(now, @season_start)
      cycle = div(current_week - 1, @weeks) + 1
      week = rem(current_week - 1, @weeks) + 1

      if Games.list_games_by_cycle(cycle) == [] do
        generate_and_insert_games(teams, @weeks, @games_per_week, @season_start |> DateTime.new!(~T[00:00:00], "Etc/UTC"), cycle)
      end

      games = Games.list_games_by_week_and_cycle(week, cycle)
      games = decorate_games(games, now)
      games = sort_games_by_time(games)

      # Load placed bets if user is logged in
      placed_bets = Bets.evaluate_and_update_user_bets(current_user.id)

      # Load draft bets if user is logged in
      bet_slip =
        Bets.list_draft_bets(current_user.id)
        |> Enum.map(fn draft ->
          %{
            game_id: draft.game_id,
            game_desc: draft.game_desc,
            type: draft.type,
            odds: draft.odds,
            stake: draft.stake
          }
        end)

      {:ok,
       socket
       |> assign(:sport, "football")
       |> assign(:week, week)
       |> assign(:tab, "upcoming")
       |> assign(:games, games)
       |> assign(:filtered_games, filter_and_sort_games(games, "upcoming"))
       |> assign(:now, now)
       |> assign(:cycle, cycle)
       |> assign(:teams, teams)
       |> assign(:season_start, @season_start)
       |> assign(:bet_slip, bet_slip)
       |> assign(:bet_slip_open, bet_slip != [])
       |> assign(:dashboard_view, "games")
       |> assign(:placed_bets, placed_bets)
       |> assign(:selected_odds, %{})
       |> assign(:current_user, current_user)
       |> assign(:bet_stake, nil)
       |> assign(:show_deposit_modal, false)
       |> assign(:history, UserHistories.list_user_histories(current_user.id))
       |> assign(:show_bet_modal, false)
       |> assign(:selected_bet, nil)}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    filtered_games = filter_and_sort_games(socket.assigns.games, tab)
    {:noreply, assign(socket, tab: tab, filtered_games: filtered_games)}
  end

  @impl true
  def handle_event("change_week", %{"week" => week}, socket) do
    teams = socket.assigns.teams
    cycle = socket.assigns.cycle
    season_start = socket.assigns.season_start
    now = DateTime.utc_now()
    {week, cycle} =
      case week do
        "all" -> {"all", cycle}
        w ->
          w = String.to_integer(w)
          if w > @weeks do
            new_cycle = cycle + 1
            if Games.list_games_by_cycle(new_cycle) == [] do
              generate_and_insert_games(teams, @weeks, @games_per_week, season_start |> DateTime.new!(~T[00:00:00], "Etc/UTC"), new_cycle)
            end
            {1, new_cycle}
          else
            {w, cycle}
          end
      end
    games =
      if week == "all" do
        Games.list_games_by_cycle(cycle)
      else
        Games.list_games_by_week_and_cycle(week, cycle)
      end
    games = decorate_games(games, now)
    games = sort_games_by_time(games)
    filtered_games = filter_and_sort_games(games, socket.assigns.tab)
    {:noreply,
      socket
      |> assign(:week, week)
      |> assign(:cycle, cycle)
      |> assign(:games, games)
      |> assign(:filtered_games, filtered_games)
    }
  end

  @impl true
  def handle_event("toggle_bet_slip", _params, socket) do
    bet_slip_open = !socket.assigns[:bet_slip_open]
    if bet_slip_open do
      send(self(), :open_bet_slip)
    else
      send(self(), :close_bet_slip)
    end
    {:noreply, assign(socket, bet_slip_open: bet_slip_open)}
  end

  @impl true
  def handle_event("add_to_bet_slip", %{"game_id" => game_id, "bet_type" => bet_type}, socket) do
    if !socket.assigns[:current_user] do
      {:noreply,
        socket
        |> Phoenix.LiveView.put_flash(:info, "Please log in to place a bet.")
        |> Phoenix.LiveView.push_redirect(to: "/users/log_in")
      }
    else
      game = Enum.find(socket.assigns.games, &("#{&1.id}" == game_id))
      if game do
        odds =
          case bet_type do
            "win" -> game.odds.win
            "draw" -> game.odds.draw
            "loss" -> game.odds.loss
            _ -> game.odds.win
          end
        bet = %{
          game_id: game.id,
          game_desc: "#{game.team_a} vs #{game.team_b}",
          type: String.capitalize(bet_type),
          odds: odds,
          stake: socket.assigns[:bet_stake] || 1
        }
        bet_slip = socket.assigns.bet_slip || []
        # Remove any existing bet for this game
        bet_slip = Enum.reject(bet_slip, &(&1.game_id == bet.game_id))
        bet_slip = [bet | bet_slip]
        # Track selected odds, only one per game
        selected_odds = socket.assigns[:selected_odds] || %{}
        selected_odds = Enum.reduce(["Win", "Draw", "Loss"], selected_odds, fn t, acc -> Map.delete(acc, {game.id, t}) end)
        selected_odds = Map.put(selected_odds, {game.id, bet.type}, true)
        {:noreply, assign(socket, bet_slip: bet_slip, bet_slip_open: true, selected_odds: selected_odds)}
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info(:open_bet_slip, socket) do
    Phoenix.LiveView.push_event(socket, "bet_slip_open", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_bet_slip, socket) do
    Phoenix.LiveView.push_event(socket, "bet_slip_close", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_history", _params, socket) do
    {:noreply, assign(socket, dashboard_view: "history")}
  end

  @impl true
  def handle_event("show_bets", _params, socket) do
    {:noreply, assign(socket, dashboard_view: "bets")}
  end

  @impl true
  def handle_event("show_games", _params, socket) do
    {:noreply, assign(socket, dashboard_view: "games")}
  end

  @impl true
  def handle_event("cancel_bet", %{"bet_id" => bet_id}, socket) do
    bet_id = String.to_integer(bet_id)
    placed_bets = socket.assigns.placed_bets
    bet = Enum.find(placed_bets, &(&1.id == bet_id))

    # Only allow cancel if the bet is pending
    if bet && bet.status == "pending" do
      case Bets.cancel_bet(bet) do
        {:ok, cancelled_bet} ->
          # Create a history entry
          UserHistories.create_user_history(%{
            user_id: socket.assigns.current_user.id,
            info: "Bet ##{cancelled_bet.id} cancelled and refunded.",
            type: "bet_cancelled",
            ref_id: cancelled_bet.id
          })

          # Reload placed bets and history
          placed_bets =
            if socket.assigns.current_user do
              Bets.list_placed_bets(socket.assigns.current_user.id)
              |> Bets.preload_selections()
            else
              []
            end
          history = UserHistories.list_user_histories(socket.assigns.current_user.id)

          {:noreply,
           socket
           |> assign(:placed_bets, placed_bets)
           |> assign(:history, history)
           |> put_flash(:info, "Bet ##{bet_id} cancelled.")
           |> assign(:show_bet_modal, false)}
        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to cancel bet.")
           |> assign(:show_bet_modal, false)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Cannot cancel this bet.")
       |> assign(:show_bet_modal, false)}
    end
  end

  @impl true
  def handle_event("save_and_close_bet_slip", _params, socket) do
    if socket.assigns.current_user do
      Bets.save_bet_slip(socket.assigns.current_user.id, socket.assigns.bet_slip)
    end

    {:noreply,
     socket
     |> assign(:bet_slip_open, false)}
  end

  @impl true
  def handle_event("clear_bet_slip", _params, socket) do
    if socket.assigns.current_user do
      Bets.clear_draft_bets(socket.assigns.current_user.id)
    end

    {:noreply,
     socket
     |> assign(:bet_slip, [])
     |> assign(:selected_odds, %{})
     |> assign(:bet_slip_open, false)}
  end

  @impl true
  def handle_event("remove_bet", %{"game_id" => game_id, "bet_type" => bet_type}, socket) do
    game_id = String.to_integer(game_id)
    bet_type_cap = String.capitalize(bet_type)

    bet_slip = Enum.reject(socket.assigns.bet_slip, &(&1.game_id == game_id and &1.type == bet_type_cap))
    selected_odds = Map.delete(socket.assigns.selected_odds, {game_id, bet_type_cap})

    # Save the updated bet slip only if not empty, otherwise delete all drafts
    if socket.assigns.current_user do
      if Enum.any?(bet_slip) do
        Bets.save_bet_slip(socket.assigns.current_user.id, bet_slip)
      else
        Bets.delete_all_draft_bets(socket.assigns.current_user.id)
      end
    end

    {:noreply,
     socket
     |> assign(:bet_slip, bet_slip)
     |> assign(:selected_odds, selected_odds)
     |> assign(:bet_slip_open, bet_slip != [])}
  end

  @impl true
  def handle_event("update_all_stakes", %{"stake" => stake}, socket) do
    {stake, _} = Integer.parse(stake)
    bet_slip = Enum.map(socket.assigns.bet_slip, fn bet -> Map.put(bet, :stake, stake) end)

    # Save the updated bet slip
    if socket.assigns.current_user do
      Bets.save_bet_slip(socket.assigns.current_user.id, bet_slip)
    end

    {:noreply,
     socket
     |> assign(:bet_slip, bet_slip)
     |> assign(:bet_stake, stake)}
  end

  @impl true
  def handle_event("update_stake", %{"stake" => stake}, socket) do
    stake =
      case Integer.parse(stake) do
        {val, _} when val > 0 -> val
        _ -> nil
      end
    bet_slip = Enum.map(socket.assigns.bet_slip,
      fn bet -> Map.put(bet, :stake, stake) end
    )
    {:noreply, assign(socket, bet_stake: stake, bet_slip: bet_slip)}
    end

  @impl true
  def handle_event("redirect_to_login", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Please log in to place bets.")
     |> redirect(to: ~p"/users/log_in")}
  end

  @impl true
  def handle_event("show_deposit_modal", _params, socket) do
    {:noreply, assign(socket, show_deposit_modal: true)}
  end

  @impl true
  def handle_event("hide_deposit_modal", _params, socket) do
    {:noreply, assign(socket, show_deposit_modal: false)}
  end

  def handle_event("show_bet_modal", %{"bet_id" => bet_id}, socket) do
    bet_id = String.to_integer(bet_id)
    bet = Enum.find(socket.assigns.placed_bets, &(&1.id == bet_id))
    {:noreply, assign(socket, show_bet_modal: true, selected_bet: bet)}
  end

  def handle_event("show_bet_modal", %{"bet_id" => bet_id}, socket) do
    bet_id = String.to_integer(bet_id)
    bet = Enum.find(socket.assigns.placed_bets, &(&1.id == bet_id))
    {:noreply, assign(socket, show_bet_modal: true, selected_bet: bet)}
  end

  @impl true
def handle_event("cancel_bet", %{"bet_id" => bet_id}, socket) do
  bet = Bets.get_bet!(bet_id)

  # Add any checks here if needed, like only allowing canceling if status is "pending"
  {:ok, _} = Bets.delete_bet(bet)

  placed_bets = Bets.list_user_placed_bets(socket.assigns.current_user.id)

  {:noreply, assign(socket, :placed_bets, placed_bets)}
end

  @impl true
  def handle_event("submit_deposit", %{"amount" => amount}, socket) do
    try do
      # Validate amount is a valid decimal, but pass as string to create_deposit
      _ = Decimal.new(amount)
      case Transactions.create_deposit(socket.assigns.current_user, amount) do
        {:ok, _transaction} ->
          # Reload the current user to get updated wallet balance
          current_user = BetZone.Accounts.get_user!(socket.assigns.current_user.id)
          {:noreply,
           socket
           |> assign(:current_user, current_user)
           |> assign(:show_deposit_modal, false)
           |> put_flash(:info, "Successfully deposited KSH #{amount}")}
        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to process deposit")
           |> assign(:show_deposit_modal, false)}
      end
    rescue
      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid amount")
         |> assign(:show_deposit_modal, false)}
    end
  end

  @impl true
  def handle_event("place_bets", _params, socket) do
    user = socket.assigns.current_user
    bet_slip = socket.assigns.bet_slip
    total_stake = socket.assigns.bet_stake * length(bet_slip)
    total_odds = Enum.reduce(bet_slip, 1, fn bet, acc -> acc * bet.odds end)
    potential_win = total_odds * socket.assigns.bet_stake

    if user.wallet >= total_stake do
      # Create the placed bet
      placed_bet_attrs = %{
        user_id: user.id,
        total_odds: total_odds,
        stake_amount: total_stake,
        potential_win: potential_win,
        status: "pending"
      }

      case Bets.create_placed_bet(placed_bet_attrs, bet_slip) do
        {:ok, placed_bet} ->
          # Create transaction for the bet placement
          {:ok, _transaction} = Transactions.create_bet_transaction(user, placed_bet, "bet_place")

          # Clear the bet slip
          Bets.delete_all_draft_bets(user.id)

          {:noreply,
           socket
           |> assign(:bet_slip, [])
           |> assign(:selected_odds, %{})
           |> assign(:bet_slip_open, false)
           |> put_flash(:info, "Bets placed successfully!")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to place bets. Please try again.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Insufficient funds. Please deposit more money.")
       |> assign(:show_deposit_modal, true)}
    end
  end

  defp week_number(now, season_start) do
    days = Date.diff(DateTime.to_date(now), season_start)
    div(days, 7) + 1
  end

  defp sort_games_by_time(games) do
    Enum.sort_by(games, & &1.scheduled_time, {:asc, DateTime})
  end

  defp filter_and_sort_games(games, tab) do
    filtered =
      case tab do
        "games" -> games # No filtering, show all games
        "ongoing" -> Enum.filter(games, &(&1.status == :ongoing))
        "completed" -> Enum.filter(games, &(&1.status == :completed))
        _ -> games
      end
    sort_games_by_time(filtered)
  end

  defp generate_and_insert_games(teams, weeks, games_per_week, season_start_dt, cycle) do
    IO.puts("Yoo, #{teams}")
    team_ids = Enum.map(teams, & &1.id)
    Enum.each(1..weeks, fn week ->
      week_start = DateTime.add(season_start_dt, ((cycle - 1) * weeks + (week - 1)) * 7 * 24 * 60 * 60, :second)
      pairs = random_unique_pairs(team_ids, games_per_week)
      Enum.with_index(pairs, 1)
      |> Enum.each(fn {{team_a_id, team_b_id}, _id} ->
        day_offset = :rand.uniform(7) - 1
        hour = Enum.random(8..23)
        minute = Enum.random([0, 15, 30, 45])
        scheduled_time =
          week_start
          |> DateTime.add(day_offset * 24 * 60 * 60, :second)
          |> DateTime.add(hour * 60 * 60 + minute * 60, :second)
        odds = random_odds()
        Games.create_game(%{
          team_a_id: team_a_id,
          team_b_id: team_b_id,
          scheduled_time: scheduled_time,
          odds_win: odds.win,
          odds_draw: odds.draw,
          odds_loss: odds.loss,
          status: "upcoming",
          score_a: nil,
          score_b: nil,
          week: week,
          cycle: cycle
        })
      end)
    end)
  end

  # Helper to calculate deterministic live score for ongoing games
  defp live_score(game, now) do
    elapsed = max(0, min(10, div(DateTime.diff(now, game.scheduled_time), 60)))
    # Use a deterministic seed based on game id and elapsed
    :rand.seed(:exsplus, {game.id, elapsed, 42})
    a = :rand.uniform(3) - 1 + rem(game.id, 2) # 0..3
    b = :rand.uniform(3) - 1 # 0..2
    {a, b, elapsed}
  end

  defp decorate_games(games, now) do
    team_map =
      BetZone.Teams.list_teams()
      |> Enum.reduce(%{}, fn team, acc -> Map.put(acc, team.id, team.name) end)

    Enum.map(games, fn game ->
      status = game_status(game.scheduled_time, now)
      odds = %{win: game.odds_win, draw: game.odds_draw, loss: game.odds_loss}
      {score, elapsed} =
        cond do
          status == :ongoing ->
            {a, b, elapsed} = live_score(game, now)
            {{a, b}, elapsed}
          status == :completed and (is_nil(game.score_a) or is_nil(game.score_b)) ->
            a = Enum.random(0..5)
            b = Enum.random(0..5)
            BetZone.Games.update_game(game, %{score_a: a, score_b: b})
            {{a, b}, 10}
          true ->
            {{game.score_a, game.score_b}, 10}
        end
      team_a = Map.get(team_map, game.team_a_id, "?")
      team_b = Map.get(team_map, game.team_b_id, "?")
      Map.merge(game, %{status: status, odds: odds, score: score, team_a: team_a, team_b: team_b, elapsed: elapsed})
    end)
  end

  defp random_unique_pairs(list, count) do
    all_pairs =
      for a <- list, b <- list, a != b, do: {a, b}
    all_pairs
    |> Enum.uniq_by(fn {a, b} -> Enum.sort([a, b]) end)
    |> Enum.shuffle()
    |> Enum.take(count)
  end

  defp random_odds do
    %{
      win: Float.round(:rand.uniform() * 2 + 1, 2),
      draw: Float.round(:rand.uniform() * 2 + 1, 2),
      loss: Float.round(:rand.uniform() * 2 + 1, 2)
    }
  end

  defp game_status(scheduled_time, now) do
    cond do
      DateTime.compare(scheduled_time, now) == :gt -> :upcoming
      DateTime.diff(now, scheduled_time) < 10 * 60 -> :ongoing # 10 minutes for a match
      true -> :completed
    end
  end

  defp filter_games_by_tab(games, tab) do
    case tab do
      "upcoming" -> Enum.filter(games, &(&1.status == :upcoming))
      "ongoing" -> Enum.filter(games, &(&1.status == :ongoing))
      "completed" -> Enum.filter(games, &(&1.status == :completed))
      _ -> games
    end
  end

  # Add a helper to render a hidden form for bet intent
  def bet_intent_form(game_id, bet_type) do
    Phoenix.HTML.Form.form_tag("/bet_intent/store", method: :post, id: "bet-intent-form-#{game_id}-#{bet_type}", style: "display:none;") do
      Phoenix.HTML.Form.hidden_input(:bet_intent, :game_id, value: game_id) <>
      Phoenix.HTML.Form.hidden_input(:bet_intent, :bet_type, value: bet_type)
    end
  end

  # Handle cancel_bet from modal component
  @impl true
  def handle_info({:cancel_bet, bet_id}, socket) do
    IO.inspect({:cancel_bet_event, bet_id: bet_id, placed_bets: socket.assigns.placed_bets}, label: "[DEBUG] handle_info cancel_bet")
    placed_bets = socket.assigns.placed_bets
    bet = Enum.find(placed_bets, &(&1.id == bet_id))

    if bet && bet.status == "pending" do
      case Bets.cancel_bet(bet) do
        {:ok, cancelled_bet} ->
          IO.inspect({:cancelled_bet, cancelled_bet: cancelled_bet}, label: "[DEBUG] cancelled_bet")
          UserHistories.create_user_history(%{
            user_id: socket.assigns.current_user.id,
            info: "Bet ##{cancelled_bet.id} cancelled and refunded.",
            type: "bet_cancelled",
            ref_id: cancelled_bet.id
          })

          placed_bets =
            if socket.assigns.current_user do
              Bets.list_placed_bets(socket.assigns.current_user.id)
              |> Bets.preload_selections()
            else
              []
            end
          history = UserHistories.list_user_histories(socket.assigns.current_user.id)

          {:noreply,
           socket
           |> assign(:placed_bets, placed_bets)
           |> assign(:history, history)
           |> put_flash(:info, "Bet ##{bet_id} cancelled.")
           |> assign(:show_bet_modal, false)}
        {:error, reason} ->
          IO.inspect({:cancel_bet_error, reason: reason}, label: "[DEBUG] cancel_bet_error")
          {:noreply,
           socket
           |> put_flash(:error, "Failed to cancel bet.")
           |> assign(:show_bet_modal, false)}
      end
    else
      IO.inspect({:cancel_bet_invalid, bet: bet}, label: "[DEBUG] cancel_bet_invalid")
      {:noreply,
       socket
       |> put_flash(:error, "Cannot cancel this bet.")
       |> assign(:show_bet_modal, false)}
    end
  end
end
