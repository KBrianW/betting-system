defmodule BetZoneWeb.Router do
  use BetZoneWeb, :router

  import BetZoneWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :app do
    plug :put_root_layout, html: {BetZoneWeb.Layouts, :app}
  end

  pipeline :super_app do
    plug :put_root_layout, html: {BetZoneWeb.Layouts, :super_app}
  end

  pipeline :panel do
    plug :put_root_layout, html: {BetZoneWeb.Layouts, :panel}
  end

  pipeline :root do
  plug :put_root_layout, html: {BetZoneWeb.Layouts, :root}
end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # User Dashboard Scope
  scope "/", BetZoneWeb do
    pipe_through [:browser, :app]
    live "/dashboard", DashboardLive, :index
    live "/basketball", OtherSportsLive, :basketball
    live "/tennis", OtherSportsLive, :tennis
    live "/rugby", OtherSportsLive, :rugby
    live "/volleyball", OtherSportsLive, :volleyball
    live "/hockey", OtherSportsLive, :hockey
    live "/history", HistoryLive
  end

  # Super User Dashboard Scope
  scope "/", BetZoneWeb do
    pipe_through [:browser, :super_app]
    live "/super_panel", SuperPanelLive, :index
    live "/super_basketball", OtherSportsLive, :basketball
    live "/super_tennis", OtherSportsLive, :tennis
    live "/super_rugby", OtherSportsLive, :rugby
    live "/super_volleyball", OtherSportsLive, :volleyball
    live "/super_hockey", OtherSportsLive, :hockey
  end

  # Admin Panel Scope
  scope "/", BetZoneWeb do
    pipe_through [:browser, :panel]
    live "/admin_panel", AdminPanelLive, :index
  end

  # Authentication and General User Actions Scope
  scope "/", BetZoneWeb do
    pipe_through [:browser, :root]
    get "/", RedirectController, :dashboard_redirect # Set root path to redirect to dashboard
    delete "/users/register", RedirectController, :register_redirect
    live "/users/register", UserRegistrationLive, :new
    live "/users/log_in", UserLoginLive, :new
    post "/users/log_in", UserSessionController, :create
    post "/users/log_out", UserSessionController, :delete
    live "/users/reset_password", UserForgotPasswordLive, :new
    live "/users/reset_password/:token", UserResetPasswordLive, :edit
    live "/users/confirm", UserConfirmationInstructionsLive, :new
    live "/users/confirm/:token", UserConfirmationLive, :edit
    live "/users/settings", UserSettingsLive, :edit
    live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    post "/bet_intent/store", BetIntentController, :store
  end

  # Other scopes may use custom stacks.
  # scope "/api", BetZoneWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bet_zone, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BetZoneWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
