defmodule BetZoneWeb.HistoryLive do
  use BetZoneWeb, :live_view
  alias BetZone.Transactions
  alias BetZone.Bets
  alias BetZone.Games

  on_mount {BetZoneWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    transactions = Transactions.list_user_transactions(socket.assigns.current_user.id)
    {:ok, assign(socket, :transactions, transactions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="bg-white rounded-lg shadow-lg p-6">
        <h2 class="text-2xl font-bold mb-6">Transaction History</h2>

        <div class="space-y-4">
          <%= for transaction <- @transactions do %>
            <div class={[
              "p-4 rounded-lg border",
              transaction_color_class(transaction.type)
            ]}>
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="font-semibold text-lg">
                    <%= transaction_title(transaction) %>
                  </h3>
                  <p class="text-gray-600">
                    <%= transaction.description %>
                  </p>
                  <p class="text-sm text-gray-500">
                    <%= Calendar.strftime(transaction.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </p>
                </div>
                <div class={[
                  "font-bold text-lg",
                  amount_color_class(transaction.type)
                ]}>
                  <%= amount_with_sign(transaction) %>
                </div>
              </div>
            </div>
          <% end %>

          <%= if Enum.empty?(@transactions) do %>
            <div class="text-center py-8 text-gray-500">
              No transaction history available
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for display
  defp transaction_title(%{type: "deposit"}), do: "Deposit"
  defp transaction_title(%{type: "withdrawal"}), do: "Withdrawal"
  defp transaction_title(%{type: "bet_place"}), do: "Bet Placed"
  defp transaction_title(%{type: "bet_win"}), do: "Bet Won"
  defp transaction_title(%{type: "bet_loss"}), do: "Bet Lost"

  defp transaction_color_class("deposit"), do: "bg-green-50 border-green-200"
  defp transaction_color_class("withdrawal"), do: "bg-orange-50 border-orange-200"
  defp transaction_color_class("bet_place"), do: "bg-blue-50 border-blue-200"
  defp transaction_color_class("bet_win"), do: "bg-green-50 border-green-200"
  defp transaction_color_class("bet_loss"), do: "bg-red-50 border-red-200"
  defp transaction_color_class(_), do: "bg-gray-50 border-gray-200"

  defp amount_color_class("deposit"), do: "text-green-600"
  defp amount_color_class("withdrawal"), do: "text-orange-600"
  defp amount_color_class("bet_place"), do: "text-blue-600"
  defp amount_color_class("bet_win"), do: "text-green-600"
  defp amount_color_class("bet_loss"), do: "text-red-600"
  defp amount_color_class(_), do: "text-gray-600"

  defp amount_with_sign(%{type: type, amount: amount}) when type in ["deposit", "bet_win"] do
    "+" <> format_amount(amount)
  end

  defp amount_with_sign(%{type: type, amount: amount}) when type in ["withdrawal", "bet_place", "bet_loss"] do
    "-" <> format_amount(amount)
  end

  defp amount_with_sign(%{amount: amount}), do: format_amount(amount)

  defp format_amount(amount) do
    "KSH " <> Decimal.to_string(Decimal.round(amount, 2))
  end
end
