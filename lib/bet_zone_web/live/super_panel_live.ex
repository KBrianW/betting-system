defmodule BetZoneWeb.SuperPanelLive do
  use BetZoneWeb, :live_view

  alias BetZone.Accounts
  alias BetZone.Teams
  alias BetZone.Games

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
      sports = ["football", "basketball", "tennis", "rugby", "volleyball", "hockey"]

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:active_page, "dashboard")
       |> assign(:active_tab, "active")
       |> assign(:users, users)
       |> assign(:sports, sports)
       |> assign(:selected_sport, nil)
       |> assign(:show_sport_dropdown, false)}
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
  def handle_event("select_sport", %{"sport" => sport}, socket) do
    {:noreply,
     socket
     |> assign(:selected_sport, sport)
     |> assign(:show_sport_dropdown, false)}
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

  # Helper functions
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
      %{key: "inactive", label: "Inactive", icon: "x-circle"},
      %{key: "pending", label: "Pending", icon: "clock"}
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
      "pending" -> filter_users_by_status(users, :pending) |> filter_non_admins_if_admin(current_user_role)
      "admins" -> if current_user_role == :super_user, do: filter_users_by_role(users, :admin), else: []
    end
  end

  defp filter_non_admins_if_admin(users, :admin) do
    Enum.filter(users, &(&1.role == :frontend))
  end
  defp filter_non_admins_if_admin(users, _), do: users

  defp get_page_icon(page) do
    case page do
      "dashboard" -> "home"
      "users" -> "users"
      "game_categories" -> "folder"
      "games" -> "play"
      "teams" -> "user-group"
      _ -> "document"
    end
  end

  defp get_tab_icon(tab) do
    case tab do
      "active" -> "check-circle"
      "inactive" -> "x-circle"
      "pending" -> "clock"
      "admins" -> "shield-check"
      _ -> "document"
    end
  end
end
