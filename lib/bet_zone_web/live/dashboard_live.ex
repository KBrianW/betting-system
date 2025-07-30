defmodule BetZoneWeb.DashboardLive do
  use BetZoneWeb, :live_view
  # Remove authentication requirement for dashboard
  # on_mount {BetZoneWeb.UserAuth, :ensure_authenticated}
  alias BetZone.Teams
  alias BetZone.Games
  alias BetZone.Bets
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
      sports = BetZone.Sports.list_active_sports()
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

      # Evaluate and update all user bets to ensure correct status
      Bets.evaluate_and_update_user_bets(current_user.id)

      # Load placed bets after evaluation
      placed_bets = Bets.list_placed_bets(current_user.id) |> Bets.preload_selections()

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
       |> assign(:sports, sports)
       |> assign(:season_start, @season_start)
       |> assign(:bet_slip, bet_slip)
       |> assign(:bet_slip_open, bet_slip != [])
       |> assign(:dashboard_view, "games")
       |> assign(:placed_bets, placed_bets)
       |> assign(:selected_odds, %{})
       |> assign(:current_user, current_user)
       |> assign(:bet_stake, 50)
       |> assign(:show_deposit_modal, false)
       |> assign(:history, UserHistories.list_user_histories(current_user.id))
       |> assign(:show_bet_modal, false)
       |> assign(:selected_bet, nil)
       |> assign(:show_cancel_confirm, false)
       |> assign(:bet_to_cancel, nil)
       |> assign(:test, "H")}
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
  def handle_event("filter_by_sport", %{"sport_id" => sport_id}, socket) do
    sport_id = String.to_integer(sport_id)
    # Filter games by sport
    filtered_games = Enum.filter(socket.assigns.games, &(&1.sport_id == sport_id))
    filtered_games = filter_and_sort_games(filtered_games, socket.assigns.tab)

    # Find the selected sport for better messaging
    selected_sport = Enum.find(socket.assigns.sports, &(&1.id == sport_id))

    {:noreply, assign(socket, filtered_games: filtered_games, selected_sport_name: selected_sport && selected_sport.name)}
  end

  @impl true
  def handle_event("show_all_sports", _params, socket) do
    # Reset to show all games
    filtered_games = filter_and_sort_games(socket.assigns.games, socket.assigns.tab)
    {:noreply, assign(socket, filtered_games: filtered_games, selected_sport_name: nil)}
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
        |> Phoenix.LiveView.push_navigate(to: "/users/log_in")
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
          stake: socket.assigns[:bet_stake] || 50
        }
        bet_slip = socket.assigns.bet_slip || []
        # Remove any existing bet for this game and bet type (allow multiple games, but only one bet type per game)
        bet_slip = Enum.reject(bet_slip, &(&1.game_id == bet.game_id && &1.type == bet.type))
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
  def handle_event("request_cancel_bet", %{"bet_id" => bet_id}, socket) do
    {:noreply, assign(socket,
      show_cancel_confirm: true,
      bet_to_cancel: bet_id
    )}
  end

  @impl true
  def handle_event("hide_cancel_confirm", _, socket) do
    {:noreply, assign(socket,
      show_cancel_confirm: false,
      bet_to_cancel: nil
    )}
  end

  @impl true
  def handle_event("confirm_cancel_bet", %{"bet_id" => bet_id}, socket) do
    socket = assign(socket, show_cancel_confirm: false)
    handle_event("cancel_bet", %{"bet_id" => bet_id}, socket)
  end

  @impl true
  def handle_event("cancel_bet", %{"bet_id" => bet_id}, socket) do
    bet_id = String.to_integer(bet_id)
    bet = Enum.find(socket.assigns.placed_bets, &(&1.id == bet_id))

    if bet && bet.status in ["pending", "active"] do
      case Bets.cancel_bet(bet) do
        {:ok, cancelled_bet} ->
          # Reload user to get updated wallet balance
          current_user = BetZone.Accounts.get_user!(socket.assigns.current_user.id)

          # Reload placed bets
          placed_bets = Bets.list_placed_bets(current_user.id) |> Bets.preload_selections()

          # Create appropriate history message based on bet status
          history_message = if bet.status == "pending" do
            "Pending bet ##{cancelled_bet.id} cancelled (no refund - no money was taken)."
          else
            "Bet ##{cancelled_bet.id} cancelled and refunded."
          end

          UserHistories.create_user_history(%{
            user_id: current_user.id,
            info: history_message,
            type: "bet_cancelled",
            ref_id: cancelled_bet.id
          })

          # Create appropriate flash message based on bet status
          flash_message = if bet.status == "pending" do
            "Pending bet ##{bet_id} cancelled (no refund needed)."
          else
            "Bet ##{bet_id} cancelled and refunded."
          end

          {:noreply,
           socket
           |> assign(:current_user, current_user)
           |> assign(:placed_bets, placed_bets)
           |> put_flash(:info, flash_message)}

        {:error, _reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to cancel bet.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Cannot cancel this bet - it may have already been processed.")}
    end
  end

  @impl true
  def handle_event("save_and_close_bet_slip", _params, socket) do
    if socket.assigns.current_user && socket.assigns.bet_slip && Enum.any?(socket.assigns.bet_slip) do
      # Save bet slip as pending bet in placed_bets table
      user = socket.assigns.current_user
      bet_slip = socket.assigns.bet_slip
      total_stake = (socket.assigns.bet_stake || 50) * length(bet_slip)
      total_odds = Enum.reduce(bet_slip, 1, fn bet, acc -> acc * bet.odds end)
      potential_win = total_odds * (socket.assigns.bet_stake || 50)

      placed_bet_attrs = %{
        user_id: user.id,
        total_odds: total_odds,
        stake_amount: total_stake,
        potential_win: potential_win,
        status: "pending"
      }

      case Bets.create_placed_bet(placed_bet_attrs, bet_slip) do
        {:ok, _placed_bet} ->
          # Clear the bet slip and reload placed bets
          placed_bets = Bets.list_placed_bets(user.id) |> Bets.preload_selections()
          {:noreply,
           socket
           |> assign(:bet_slip, [])
           |> assign(:selected_odds, %{})
           |> assign(:bet_slip_open, false)
           |> assign(:placed_bets, placed_bets)
           |> put_flash(:info, "Bet saved as pending.")}
        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(:bet_slip_open, false)
           |> put_flash(:error, "Failed to save bet.")}
      end
    else
      {:noreply,
       socket
       |> assign(:bet_slip_open, false)}
    end
  end

  @impl true
  def handle_event("save_draft_and_close", _params, socket) do
    if socket.assigns.current_user && socket.assigns.bet_slip && Enum.any?(socket.assigns.bet_slip) do
      # Save bet slip as draft
      Bets.save_bet_slip(socket.assigns.current_user.id, socket.assigns.bet_slip)
      {:noreply,
       socket
       |> assign(:bet_slip_open, false)
       |> put_flash(:info, "Bet slip saved as draft.")}
    else
      {:noreply,
       socket
       |> assign(:bet_slip_open, false)}

    end
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

    {:noreply,
     socket
     |> assign(:bet_slip, bet_slip)
     |> assign(:selected_odds, selected_odds)
     |> assign(:bet_slip_open, bet_slip != [])}
  end

  @impl true
  def handle_event("update_stake", %{"stake" => stake}, socket) do
    stake =
      case Integer.parse(stake) do
        {val, _} when val >= 50 -> val
        _ -> 50
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

  # Handle noop event to prevent click propagation in bet slip
  @impl true
  def handle_event("noop", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_pending_bet", %{"bet_id" => bet_id}, socket) do
    bet_id = String.to_integer(bet_id)
    bet = Enum.find(socket.assigns.placed_bets, &(&1.id == bet_id))

    if bet && bet.status == "pending" do
      # Convert placed bet back to bet slip format
      bet_slip = Enum.map(bet.selections, fn selection ->
        %{
          game_id: selection.game_id,
          game_desc: selection.game_desc,
          type: selection.selection_type,
          odds: selection.odds,
          stake: Decimal.to_integer(Decimal.div(bet.stake_amount, length(bet.selections)))
        }
      end)

      # Filter out games that are ongoing or completed
      now = DateTime.utc_now()
      games = socket.assigns.games
      valid_bet_slip = Enum.filter(bet_slip, fn bet_item ->
        game = Enum.find(games, &(&1.id == bet_item.game_id))
        if game do
          game_status = game_status(game.scheduled_time, now)
          game_status == :upcoming
        else
          false
        end
      end)

      # Delete the pending bet since we're editing it
      Bets.delete_bet(bet)

      # Reload placed bets
      placed_bets = Bets.list_placed_bets(socket.assigns.current_user.id) |> Bets.preload_selections()

      # Show message if some games were removed
      socket = if length(valid_bet_slip) < length(bet_slip) do
        put_flash(socket, :info, "Some games were removed from your draft because they have already started or completed.")
      else
        socket
      end

      # Load into bet slip
      {:noreply,
       socket
       |> assign(:bet_slip, valid_bet_slip)
       |> assign(:bet_slip_open, true)
       |> assign(:placed_bets, placed_bets)
       |> assign(:bet_stake, if(length(valid_bet_slip) > 0, do: div(bet.stake_amount, length(bet.selections)), else: 50))
       |> assign(:dashboard_view, "games")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_bet_modal", %{"bet_id" => bet_id}, socket) do
    bet_id = String.to_integer(bet_id)
    bet = Enum.find(socket.assigns.placed_bets, &(&1.id == bet_id))
    # Force close first, then open to reset modal state
    socket = assign(socket, show_bet_modal: false)
    {:noreply, assign(socket, show_bet_modal: true, selected_bet: bet)}
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
        status: "active"
      }

      case Bets.create_placed_bet(placed_bet_attrs, bet_slip) do
        {:ok, placed_bet} ->
          # Create transaction for the bet placement
          {:ok, _transaction} = Transactions.create_bet_transaction(user, placed_bet, "bet_place")

          # Reload user to get updated wallet balance
          current_user = BetZone.Accounts.get_user!(user.id)

          # Reload placed bets
          placed_bets = Bets.list_placed_bets(user.id) |> Bets.preload_selections()

          {:noreply,
           socket
           |> assign(:bet_slip, [])
           |> assign(:selected_odds, %{})
           |> assign(:bet_slip_open, false)
           |> assign(:current_user, current_user)
           |> assign(:placed_bets, placed_bets)
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

    # Get the default sport (first available sport)
    default_sport = BetZone.Sports.list_sports() |> List.first()
    sport_id = if default_sport, do: default_sport.id, else: nil

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
          sport_id: sport_id,
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

end
