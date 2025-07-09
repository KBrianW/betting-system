defmodule BettingSystemWeb.AdminController do
  use BettingSystemWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user

    # Allow admin and super_user only
    if user.role in [:admin, :super_user] do
      render(conn, :index)
    else
      conn
      |> put_flash(:error, "You are not authorized to access the admin panel.")
      |> redirect(to: "/dashboard")
    end
  end
end
