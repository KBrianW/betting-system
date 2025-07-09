defmodule BetZoneWeb.DashboardLive do
  use BetZoneWeb, :live_view
  # Remove authentication requirement for dashboard
  # on_mount {BetZoneWeb.UserAuth, :ensure_authenticated}
  alias BetZone.Teams
  alias BetZone.Games
  alias Timex.Timex

  @weeks 8
  @games_per_week 8
  @season_start Date.utc_today() |> Date.beginning_of_week(:monday)

  @impl true
  def mount(_params, session, socket) do
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

    # Sample/mock data for history and bets
    history = [
      %{time: NaiveDateTime.utc_now(), info: "You gained $50 from winning a bet."},
      %{time: NaiveDateTime.add(NaiveDateTime.utc_now(), -2 * 60 * 60), info: "Game between Team A and Team B was postponed."},
      %{time: NaiveDateTime.add(NaiveDateTime.utc_now(), -1 * 24 * 60 * 60), info: "Insufficient funds for bet on Team C vs Team D."},
      %{time: NaiveDateTime.add(NaiveDateTime.utc_now(), -2 * 24 * 60 * 60), info: "You lost $20 on Team E vs Team F."},
      %{time: NaiveDateTime.add(NaiveDateTime.utc_now(), -3 * 24 * 60 * 60), info: "Game between Team G and Team H was cancelled."}
    ]
    bets = [
      %{id: 1, time: NaiveDateTime.add(NaiveDateTime.utc_now(), -1 * 60 * 60), desc: "Team A vs Team B (Win)", odds: 2.1, amount: 20, status: :pending, games_status: [:upcoming]},
      %{id: 2, time: NaiveDateTime.add(NaiveDateTime.utc_now(), -1 * 24 * 60 * 60), desc: "Team C vs Team D (Draw)", odds: 3.2, amount: 15, status: :pending, games_status: [:ongoing]},
      %{id: 3, time: NaiveDateTime.add(NaiveDateTime.utc_now(), -2 * 24 * 60 * 60), desc: "Team E vs Team F (Loss)", odds: 1.8, amount: 10, status: :lost, games_status: [:completed]}
    ]

    {bet_slip, selected_odds} =
      case session["intended_bet"] do
        nil -> {[], %{}}
        intended ->
          game = Enum.find(games, &("#{&1.id}" == intended["game_id"]))
          if game do
            bet_type = String.capitalize(intended["bet_type"])
            odds = case intended["bet_type"] do
              "win" -> game.odds.win
              "draw" -> game.odds.draw
              "loss" -> game.odds.loss
              _ -> game.odds.win
            end
            bet = %{
              game_id: game.id,
              game_desc: "#{game.team_a} vs #{game.team_b}",
              type: bet_type,
              odds: odds,
              stake: 1
            }
            {[bet], Map.put(%{}, {game.id, bet_type}, true)}
          else
            {[], %{}}
          end
      end

    # Assign current_user if present in session
    current_user =
      if user_token = session["user_token"] do
        BetZone.Accounts.get_user_by_session_token(user_token)
      else
        nil
      end

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
     |> assign(:history, history)
     |> assign(:bets, bets)
     |> assign(:selected_odds, selected_odds)
     |> assign(:current_user, current_user)
    }
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
          stake: 1
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
    bets = socket.assigns.bets
    bet = Enum.find(bets, &(&1.id == bet_id))
    # Only allow cancel if all games in bet are upcoming
    if bet && Enum.all?(bet.games_status, &(&1 == :upcoming)) do
      # Refund wallet logic would go here
      bets = Enum.reject(bets, &(&1.id == bet_id))
      # Add a history entry for refund
      history = [%{time: NaiveDateTime.utc_now(), info: "Bet ##{bet_id} cancelled. $#{bet.amount} refunded to wallet."} | socket.assigns.history]
      {:noreply, assign(socket, bets: bets, history: history)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_bet", %{"game_id" => game_id, "bet_type" => bet_type}, socket) do
    bet_slip = socket.assigns.bet_slip || []
    selected_odds = socket.assigns.selected_odds || %{}
    bet_type_cap = String.capitalize(bet_type)
    bet_slip = Enum.reject(bet_slip, &(&1.game_id == String.to_integer(game_id) and &1.type == bet_type_cap))
    selected_odds = Map.delete(selected_odds, {String.to_integer(game_id), bet_type_cap})
    {:noreply, assign(socket, bet_slip: bet_slip, selected_odds: selected_odds)}
  end

  @impl true
  def handle_event("clear_bet_slip", _params, socket) do
    {:noreply, assign(socket, bet_slip: [], selected_odds: %{})}
  end

  @impl true
  def handle_event("update_stake", %{"game_id" => game_id, "bet_type" => bet_type, "stake" => stake}, socket) do
    bet_slip = socket.assigns.bet_slip || []
    bet_type_cap = String.capitalize(bet_type)
    bet_slip = Enum.map(bet_slip, fn bet ->
      if bet.game_id == String.to_integer(game_id) and bet.type == bet_type_cap do
        Map.put(bet, :stake, String.to_integer(stake))
      else
        bet
      end
    end)
    {:noreply, assign(socket, bet_slip: bet_slip)}
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
end
