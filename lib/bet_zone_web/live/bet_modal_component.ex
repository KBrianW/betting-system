defmodule BetZoneWeb.BetModalComponent do
  use BetZoneWeb, :live_component

  def render(assigns) do
    ~H"""
    <div>
    <%= if @show do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center" phx-click="show_bets" phx-target={@myself}>
        <div class="bg-white rounded-lg p-6 w-96 relative" phx-click-away="show_bets" phx-target={@myself}>
          <button phx-click="show_bets" phx-target={@myself} class="absolute top-4 right-4 text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
          <h2 class="text-xl font-bold mb-4">Bet Details</h2>
          <div class="space-y-4">
            <%= for selection <- @bet.selections do %>
              <div>
                <p class="font-semibold"><%= selection.game_desc %></p>
                <p>Selection: <%= selection.selection_type %></p>
                <p>Odds: <%= selection.odds %></p>
                <p>Result: <%= selection.result %></p>
              </div>
            <% end %>
            <div class="text-sm text-gray-600">
              Total Odds: <%= @bet.total_odds %> |
              Stake: KSH <%= Decimal.round(@bet.stake_amount, 2) %> |
              Potential Win: KSH <%= Decimal.round(@bet.potential_win, 2) %> |
              Status: <%= String.capitalize(@bet.status) %>
            </div>
            <div class="flex justify-end mt-4">
              <%= if @bet.status == "pending" and Decimal.eq?(@bet.potential_win, 0)do %>
              <button
              phx-click="load_pending_bet"
              phx-value-bet_id={@bet.id}
              class="bg-green-600 text-white px-4 py-2 rounded hover:bg-orange-700 transition duration-200 text-sm"
            >
              Confirm Bet
            </button>

              <% else %>
                <button
                  phx-click="show_bets"
                  phx-target={@myself}
                  class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600 transition duration-200 text-sm"
                >
                  Close
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    </div>
    """
  end



  def handle_event("hide_bet_modal", _, socket) do
    send(socket.parent_pid, {:hide_bet_modal})
    {:noreply, socket}
  end

  def handle_event("cancel_bet", _, socket) do
   {:noreply, socket |>assign(:show, false)}
  end

  def handle_event("show_bets", _, socket) do
    {:noreply, socket |>assign(:show, false)}
  end
end
