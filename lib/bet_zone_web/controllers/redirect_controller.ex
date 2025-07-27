defmodule BetZoneWeb.RedirectController do
  use BetZoneWeb, :controller
  
  alias BetZone.Accounts

  def dashboard_redirect(conn, _params) do
    # Check if user is logged in
    case get_session(conn, :user_token) do
      nil ->
        # No user logged in, redirect to login
        redirect(conn, to: "/users/log_in")
      
      user_token ->
        # User is logged in, get user and redirect based on role
        case Accounts.get_user_by_session_token(user_token) do
          nil ->
            # Invalid token, redirect to login
            redirect(conn, to: "/users/log_in")
          
          user ->
            # Redirect based on user role
            case user.role do
              :frontend -> redirect(conn, to: "/dashboard")
              :admin -> redirect(conn, to: "/super_panel")
              :super_user -> redirect(conn, to: "/super_panel")
              _ -> redirect(conn, to: "/users/log_in")
            end
        end
    end
  end

  def register_redirect(conn, _params) do
    redirect(conn, to: "/users/register")
  end
end