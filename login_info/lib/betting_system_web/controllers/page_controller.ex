defmodule BettingSystemWeb.PageController do
  use BettingSystemWeb, :controller

def dashboard(conn, _params) do
    user = conn.assigns.current_user

    # Only allow frontend users
    if user.role == :frontend do
      render(conn, :dashboard)
    else
      conn
      |> put_flash(:error, "You are not authorized to access this page.")
      |> redirect(to: "/")
    end
  end

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
