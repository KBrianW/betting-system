defmodule BetZoneWeb.SuperPanelLive do
  use BetZoneWeb, :live_view

  alias BetZone.Accounts
  alias BetZone.Teams
  alias BetZone.Games
  alias BetZone.Sports

  @impl true
  def mount(_params, session, socket) do
    current_user =
      if user_token = session["user_token"] do
        BetZone.Accounts.get_user_by_session_token(user_token)
      else
        nil
      end

    # Check if user has admin or super_admin role
    if is_nil(current_user) or current_user.role not in [:admin, :super_user] do
      {:ok, Phoenix.LiveView.redirect(socket, to: "/users/log_in")}
    else
      # Load initial data
      users = load_users_by_role(current_user.role)
      sports = Sports.list_active_sports()
      teams = Teams.list_teams()
      games = Games.list_games()

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:active_page, "dashboard")
       |> assign(:active_tab, "active")
       |> assign(:users, users)
       |> assign(:sports, sports)
       |> assign(:teams, teams)
       |> assign(:games, games)
       |> assign(:selected_sport, nil)
       |> assign(:selected_team, nil)
       |> assign(:show_sport_dropdown, false)
       |> assign(:show_add_sport_form, false)
       |> assign(:show_add_team_form, false)
       |> assign(:show_add_game_form, false)
       |> assign(:new_sport_name, "")
       |> assign(:new_sport_emoji, "")
       |> assign(:new_team_name, "")
       |> assign(:selected_sport_for_team, nil)
       |> assign(:selected_sport_for_game, nil)
       |> assign(:selected_game_for_edit, nil)
       |> assign(:expanded_sports, MapSet.new())}
    end
  end

  @impl true
  def handle_event("navigate_to", %{"page" => page}, socket) do
    users = if page == "users", do: load_users_by_role(socket.assigns.current_user.role), else: socket.assigns.users

    {:noreply,
     socket
     |> assign(:active_page, page)
     |> assign(:active_tab, "active")
     |> assign(:users, users)}
  end

  @impl true
  def handle_event("change_user_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_sport_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_sport_dropdown, !socket.assigns.show_sport_dropdown)}
  end

  @impl true
  def handle_event("select_sport", %{"sport" => sport_id}, socket) do
    sport = Enum.find(socket.assigns.sports, &("#{&1.id}" == sport_id))
    sport_name = if sport, do: sport.name, else: nil

    {:noreply,
     socket
     |> assign(:selected_sport, sport_name)
     |> assign(:show_sport_dropdown, false)}
  end

  @impl true
  def handle_event("toggle_sport_teams", %{"sport_id" => sport_id}, socket) do
    sport_id = String.to_integer(sport_id)
    expanded_sports = socket.assigns.expanded_sports

    expanded_sports = if MapSet.member?(expanded_sports, sport_id) do
      MapSet.delete(expanded_sports, sport_id)
    else
      MapSet.put(expanded_sports, sport_id)
    end

    {:noreply, assign(socket, :expanded_sports, expanded_sports)}
  end

  @impl true
  def handle_event("promote_to_admin", %{"user_id" => user_id}, socket) do
    if socket.assigns.current_user.role == :super_user do
      user = Accounts.get_user!(user_id)
      case Accounts.update_user_role(user, :admin) do
        {:ok, _updated_user} ->
          users = load_users_by_role(socket.assigns.current_user.role)
          {:noreply,
           socket
           |> assign(:users, users)
           |> put_flash(:info, "User promoted to admin successfully.")}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to promote user.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("revoke_admin", %{"user_id" => user_id}, socket) do
    if socket.assigns.current_user.role == :super_user do
      user = Accounts.get_user!(user_id)
      case Accounts.update_user_role(user, :frontend) do
        {:ok, _updated_user} ->
          users = load_users_by_role(socket.assigns.current_user.role)
          {:noreply,
           socket
           |> assign(:users, users)
           |> put_flash(:info, "Admin revoked successfully.")}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to revoke admin.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("activate_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    case Accounts.update_user_status(user, :active) do
      {:ok, _updated_user} ->
        users = load_users_by_role(socket.assigns.current_user.role)
        {:noreply,
         socket
         |> assign(:users, users)
         |> put_flash(:info, "User activated successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to activate user.")}
    end
  end

  @impl true
  def handle_event("deactivate_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    case Accounts.update_user_status(user, :inactive) do
      {:ok, _updated_user} ->
        users = load_users_by_role(socket.assigns.current_user.role)
        {:noreply,
         socket
         |> assign(:users, users)
         |> put_flash(:info, "User deactivated successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate user.")}
    end
  end

  @impl true
  def handle_event("show_add_sport_form", _params, socket) do
    {:noreply, assign(socket, show_add_sport_form: true)}
  end

  @impl true
  def handle_event("hide_add_sport_form", _params, socket) do
    {:noreply, assign(socket, show_add_sport_form: false, new_sport_name: "", new_sport_emoji: "")}
  end

  @impl true
  def handle_event("add_sport", %{"name" => name, "emoji" => emoji}, socket) do
    case Sports.create_sport(%{name: name, emoji: emoji}) do
      {:ok, _sport} ->
        sports = Sports.list_active_sports()
        {:noreply,
         socket
         |> assign(:sports, sports)
         |> assign(:show_add_sport_form, false)
         |> assign(:new_sport_name, "")
         |> assign(:new_sport_emoji, "")
         |> put_flash(:info, "Sport added successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add sport.")}
    end
  end

  @impl true
  def handle_event("delete_sport", %{"sport_id" => sport_id}, socket) do
    sport = Sports.get_sport!(sport_id)
    case Sports.delete_sport(sport) do
      {:ok, _sport} ->
        sports = Sports.list_active_sports()
        {:noreply,
         socket
         |> assign(:sports, sports)
         |> put_flash(:info, "Sport deleted successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete sport.")}
    end
  end

  @impl true
  def handle_event("show_add_team_form", %{"sport_id" => sport_id}, socket) do
    {:noreply, assign(socket, show_add_team_form: true, selected_sport_for_team: sport_id)}
  end

  @impl true
  def handle_event("hide_add_team_form", _params, socket) do
    {:noreply, assign(socket, show_add_team_form: false, new_team_name: "", selected_sport_for_team: nil)}
  end

  @impl true
  def handle_event("add_team", %{"name" => name}, socket) do
    sport_id = socket.assigns.selected_sport_for_team
    case Teams.create_team(%{name: name, sport_id: sport_id}) do
      {:ok, _team} ->
        teams = Teams.list_teams()
        {:noreply,
         socket
         |> assign(:teams, teams)
         |> assign(:show_add_team_form, false)
         |> assign(:new_team_name, "")
         |> assign(:selected_sport_for_team, nil)
         |> put_flash(:info, "Team added successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add team.")}
    end
  end

  @impl true
  def handle_event("delete_team", %{"team_id" => team_id}, socket) do
    team = Teams.get_team!(team_id)
    case Teams.delete_team(team) do
      {:ok, _team} ->
        teams = Teams.list_teams()
        {:noreply,
         socket
         |> assign(:teams, teams)
         |> put_flash(:info, "Team deleted successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete team.")}
    end
  end

  # Games Management Event Handlers
  @impl true
  def handle_event("show_add_game_form", %{"sport_id" => sport_id}, socket) do
    {:noreply, assign(socket, show_add_game_form: true, selected_sport_for_game: sport_id)}
  end

  @impl true
  def handle_event("hide_add_game_form", _params, socket) do
    {:noreply, assign(socket, show_add_game_form: false, selected_sport_for_game: nil)}
  end

  @impl true
  def handle_event("add_game", params, socket) do
    sport_id = socket.assigns.selected_sport_for_game

    game_attrs = %{
      sport_id: sport_id,
      team_a_id: params["team_a_id"],
      team_b_id: params["team_b_id"],
      scheduled_time: parse_datetime(params["scheduled_date"], params["scheduled_time"]),
      odds_win: String.to_float(params["odds_win"]),
      odds_draw: String.to_float(params["odds_draw"]),
      odds_loss: String.to_float(params["odds_loss"]),
      week: String.to_integer(params["week"]),
      cycle: String.to_integer(params["cycle"]),
      status: "scheduled"
    }

    case Games.create_game(game_attrs) do
      {:ok, _game} ->
        games = Games.list_games()
        {:noreply,
         socket
         |> assign(:games, games)
         |> assign(:show_add_game_form, false)
         |> assign(:selected_sport_for_game, nil)
         |> put_flash(:info, "Game added successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add game.")}
    end
  end

  @impl true
  def handle_event("delete_game", %{"game_id" => game_id}, socket) do
    game = Games.get_game!(game_id)
    case Games.delete_game(game) do
      {:ok, _game} ->
        games = Games.list_games()
        {:noreply,
         socket
         |> assign(:games, games)
         |> put_flash(:info, "Game deleted successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete game.")}
    end
  end

  @impl true
  def handle_event("update_game_status", %{"game_id" => game_id, "status" => status}, socket) do
    game = Games.get_game!(game_id)
    case Games.update_game_status(game, status) do
      {:ok, _game} ->
        games = Games.list_games()
        {:noreply,
         socket
         |> assign(:games, games)
         |> put_flash(:info, "Game status updated successfully.")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update game status.")}
    end
  end

  # Helper functions
  defp parse_datetime(date_str, time_str) do
    case DateTime.from_naive(NaiveDateTime.from_iso8601!("#{date_str} #{time_str}:00"), "Etc/UTC") do
      {:ok, datetime} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp load_users_by_role(role) do
    case role do
      :super_user ->
        # Super admin can see all users including admins
        Accounts.list_users()
      :admin ->
        # Admin can only see frontend users
        Accounts.list_users_by_role(:frontend)
    end
  end

  defp filter_users_by_status(users, status) do
    Enum.filter(users, &(&1.status == status))
  end

  defp filter_users_by_role(users, role) do
    Enum.filter(users, &(&1.role == role))
  end

  defp get_user_tabs(current_user_role) do
    base_tabs = [
      %{key: "active", label: "Active", icon: "check-circle"},
      %{key: "inactive", label: "Inactive", icon: "x-circle"}
    ]

    if current_user_role == :super_user do
      base_tabs ++ [%{key: "admins", label: "Admins", icon: "shield-check"}]
    else
      base_tabs
    end
  end

  defp get_filtered_users(users, tab, current_user_role) do
    case tab do
      "active" -> filter_users_by_status(users, :active) |> filter_non_admins_if_admin(current_user_role)
      "inactive" -> filter_users_by_status(users, :inactive) |> filter_non_admins_if_admin(current_user_role)
      "admins" -> if current_user_role == :super_user, do: filter_users_by_role(users, :admin), else: []
    end
  end

  defp filter_non_admins_if_admin(users, :admin) do
    Enum.filter(users, &(&1.role == :frontend))
  end
  defp filter_non_admins_if_admin(users, _), do: users

end
