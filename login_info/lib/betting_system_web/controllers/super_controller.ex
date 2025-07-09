defmodule BettingSystemWeb.SuperController do
  use BettingSystemWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user

    # Only allow super_user
    if user.role == :super_user do
      render(conn, :index)
    else
      conn
      |> put_flash(:error, "You are not authorized to access the super panel.")
      |> redirect(to: "/dashboard")
    end
  end
end

