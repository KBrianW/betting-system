defmodule BetZoneWeb.RedirectController do
  use BetZoneWeb, :controller

  plug BetZoneWeb.UserAuth, :fetch_current_user

  def index(conn, _params) do
    case conn.assigns[:current_user] do
      nil -> redirect(conn, to: "/users/log_in")
      %{role: :frontend} -> redirect(conn, to: "/dashboard")
      %{role: :admin} -> redirect(conn, to: "/admin_panel")
      %{role: :super_user} -> redirect(conn, to: "/super_panel")
      _ -> redirect(conn, to: "/users/log_in")
    end
  end
end
