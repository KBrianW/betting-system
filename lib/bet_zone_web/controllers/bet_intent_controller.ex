defmodule BetZoneWeb.BetIntentController do
  use BetZoneWeb, :controller

  def store(conn, %{"game_id" => game_id, "bet_type" => bet_type}) do
    conn
    |> put_session(:intended_bet, %{game_id: game_id, bet_type: bet_type})
    |> redirect(to: "/users/log_in")
  end
end
