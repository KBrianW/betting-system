defmodule BetZoneWeb.OtherSportsLive do
  use BetZoneWeb, :live_view

  def mount(_params, _session, socket) do
    sport = Phoenix.LiveView.connected?(socket) && socket.assigns.live_action || "This game"
    {:ok,
      socket
      |> assign(:sport, sport)
      |> assign(:week, 1)
      |> assign(:tab, "upcoming")
      |> assign(:dashboard_view, "games")
      |> assign(:current_user, socket.assigns[:current_user])
    }
  end

  def handle_event("change_week", %{"week" => week}, socket) do
    {:noreply, assign(socket, week: week)}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: tab)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-4">
      <div>
        <h2 class="text-2xl font-bold text-gray-800"><%= String.capitalize(@sport) %> Dashboard</h2>
        <p class="text-gray-500">Welcome, <%= @current_user && @current_user.first_name || "User" %>!</p>
      </div>
    </div>
    <div class="flex items-center space-x-2 mt-4 mb-6">
      <span class="font-semibold mr-2 text-gray-700">Week:</span>
      <%= for w <- 1..8 do %>
        <button phx-click="change_week" phx-value-week={w} class={[
          "px-3 py-1 rounded border border-gray-300 text-gray-700 bg-white hover:bg-gray-100 transition",
          to_string(w) == to_string(@week) && "bg-gray-200 font-bold border-gray-400" || ""
        ]}><%= w %></button>
      <% end %>
      <button phx-click="change_week" phx-value-week="all" class={[
        "px-3 py-1 rounded border border-gray-300 text-gray-700 bg-white hover:bg-gray-100 transition",
        @week == "all" && "bg-gray-200 font-bold border-gray-400" || ""
      ]}>All</button>
    </div>
    <div class="flex space-x-4 border-b border-gray-200 mb-6">
      <button phx-click="change_tab" phx-value-tab="upcoming" class={[
        "px-4 py-2 -mb-px border-b-2 font-semibold text-gray-700 bg-white hover:bg-gray-100 transition",
        @tab == "upcoming" && "border-gray-700" || "border-transparent"
      ]}>Upcoming</button>
      <button phx-click="change_tab" phx-value-tab="ongoing" class={[
        "px-4 py-2 -mb-px border-b-2 font-semibold text-gray-700 bg-white hover:bg-gray-100 transition",
        @tab == "ongoing" && "border-gray-700" || "border-transparent"
      ]}>Ongoing</button>
      <button phx-click="change_tab" phx-value-tab="completed" class={[
        "px-4 py-2 -mb-px border-b-2 font-semibold text-gray-700 bg-white hover:bg-gray-100 transition",
        @tab == "completed" && "border-gray-700" || "border-transparent"
      ]}>Completed</button>
    </div>
    <div class="flex flex-col items-center justify-center min-h-[40vh]">
      <h1 class="text-2xl font-bold mb-4 text-gray-700">Coming Soon</h1>
      <p class="text-lg text-gray-600">This game will be added soon.</p>
    </div>
    """
  end
end
