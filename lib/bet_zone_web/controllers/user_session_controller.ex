defmodule BetZoneWeb.UserSessionController do
  use BetZoneWeb, :controller

  import Phoenix.Component, only: [to_form: 1, to_form: 2]

  alias BetZone.Accounts
  alias BetZoneWeb.UserAuth

  def new(conn, _params) do
    conn
    |> assign(:page_title, "Log in")
    |> assign(:form, to_form(%{"email" => nil, "password" => nil}, as: "user"))
    |> render(:new)
  end

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
      |> redirect_user_after_login(user)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> assign(:form, to_form(%{email: email}, as: "user"))
      |> render(:new)
    end
  end

  defp redirect_user_after_login(conn, user) do
    case user.role do
      :frontend -> redirect(conn, to: ~p"/dashboard")
      :admin -> redirect(conn, to: ~p"/admin_panel")
      :super_user -> redirect(conn, to: ~p"/super_panel")
      _ -> redirect(conn, to: "/")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
