defmodule BetZoneWeb.RedirectController do
  use BetZoneWeb, :controller

  def dashboard_redirect(conn, _params) do
    redirect(conn, to: "/dashboard")
  end

  def register_redirect(conn, _params) do
    redirect(conn, to: "/users/register")
  end
end
