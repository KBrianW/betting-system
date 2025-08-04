defmodule BetZoneWeb.AdminPanelLive do
  use BetZoneWeb, :live_view
  alias BetZone.Accounts
  alias BetZone.Bets

  @impl true
  def mount(_params, session, socket) do
    current_user =
      if user_token = session["user_token"] do
        BetZone.Accounts.get_user_by_session_token(user_token)
      else
        nil
      end

    if is_nil(current_user) or current_user.role not in [:admin, :super_user] do
      {:ok, Phoenix.LiveView.redirect(socket, to: "/users/log_in")}
    else
      users = load_users_by_role(current_user.role)

      total_income = BetZone.Bets.total_income()
      total_losses = BetZone.Bets.total_user_losses()
      profit = total_income - total_losses

      {:ok,
       socket
       |> assign(:dashboard_view, "dashboard")
       |> assign(:current_user, current_user)
       |> assign(:dashboard_tab, "users")
       |> assign(:active_tab, "users")
       |> assign(:selected_user, nil)
       |> assign(:users, users)
       |> assign(:user_bets, [])
       |> assign(:user_history, [])
       |> assign(:total_income, total_income)
       |> assign(:total_losses, total_losses)
       |> assign(:profit, profit)}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:dashboard_tab, tab) |> assign(:selected_user, nil)}
  end

  @impl true
  def handle_event("select_user", %{"user_id" => id}, socket) do
    user = Accounts.get_user!(id)
    user_bets = Bets.list_placed_bets(user.id)
    user_history = Bets.list_user_completed_bets(user.id)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:user_bets, user_bets)
     |> assign(:user_history, user_history)
     |>assign(:user_view_tab, "bets")}
  end

  @impl true
  def handle_event("navigate_to", %{"page" => page}, socket) do
    users = if page == "users", do: load_users_by_role(socket.assigns.current_user.role), else: socket.assigns.users

    {:noreply,
     socket
     |> assign(:active_page, page)
     |> assign(:dashboard_view, page)
     |> assign(:active_tab, "active")
     |> assign(:users, users)}
  end

  @impl true
  def handle_event("change_user_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("promote_to_admin", %{"user_id" => user_id}, socket) do
    if socket.assigns.current_user.role == :super_user do
      user = Accounts.get_user!(user_id)

      case Accounts.update_user_role(user, :admin) do
        {:ok, _} ->
          users = load_users_by_role(socket.assigns.current_user.role)
          {:noreply, assign(socket, :users, users) |> put_flash(:info, "User promoted to admin successfully.")}
        {:error, _} ->
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
        {:ok, _} ->
          users = load_users_by_role(socket.assigns.current_user.role)
          {:noreply, assign(socket, :users, users) |> put_flash(:info, "Admin revoked successfully.")}
        {:error, _} ->
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
      {:ok, _} ->
        users = load_users_by_role(socket.assigns.current_user.role)
        {:noreply, assign(socket, :users, users) |> put_flash(:info, "User activated successfully.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to activate user.")}
    end
  end

  @impl true
def handle_event("select_dashboard_tab", %{"tab" => "users"}, socket) do
  frontend_users = Accounts.list_users_by_role(:frontend)

  {:noreply,
   socket
   |> assign(:dashboard_tab, "users")
   |> assign(:dashboard_view, "dashboard")
   |> assign(:users, frontend_users)
   |> assign(:selected_user, nil)}
end

@impl true
def handle_event("select_dashboard_tab", %{"tab" => tab}, socket) do
  {:noreply,
   socket
   |> assign(:dashboard_tab, tab)
   |> assign(:dashboard_view, "dashboard")
   |> assign(:selected_user, nil)}
end


  @impl true
  def handle_event("deactivate_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_status(user, :inactive) do
      {:ok, _} ->
        users = load_users_by_role(socket.assigns.current_user.role)
        {:noreply, assign(socket, :users, users) |> put_flash(:info, "User deactivated successfully.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate user.")}
    end
  end

  # Helpers
  defp load_users_by_role(:super_user), do: Accounts.list_users()
  defp load_users_by_role(:admin), do: Accounts.list_users_by_role(:frontend)

  defp filter_users_by_status(users, status), do: Enum.filter(users, &(&1.status == status))
  defp filter_users_by_role(users, role), do: Enum.filter(users, &(&1.role == role))

  defp get_user_tabs(:super_user), do: [
    %{key: "active", label: "Active", icon: "check-circle"},
    %{key: "inactive", label: "Inactive", icon: "x-circle"},
    %{key: "admins", label: "Admins", icon: "shield-check"}
  ]
  defp get_user_tabs(_), do: [
    %{key: "active", label: "Active", icon: "check-circle"},
    %{key: "inactive", label: "Inactive", icon: "x-circle"}
  ]

  defp get_filtered_users(users, tab, :admin) do
    case tab do
      "active" -> filter_users_by_status(users, :active) |> Enum.filter(&(&1.role == :frontend))
      "inactive" -> filter_users_by_status(users, :inactive) |> Enum.filter(&(&1.role == :frontend))
      _ -> []
    end
  end

  defp get_filtered_users(users, tab, :super_user) do
    case tab do
      "active" -> filter_users_by_status(users, :active)
      "inactive" -> filter_users_by_status(users, :inactive)
      "admins" -> filter_users_by_role(users, :admin)
      _ -> []
    end
  end
end
