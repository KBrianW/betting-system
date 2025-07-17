defmodule BetZoneWeb.AdminPanelLive do
  use BetZoneWeb, :live_view

  alias BetZone.Accounts

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")
    {:ok,
      socket
      |> assign(:current_user, current_user)
      |> assign(:tab, "active")
      |> assign(:filter, "")
      |> assign(:users, []) # Placeholder, to be replaced with real data
    }
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("filter_users", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end
end
