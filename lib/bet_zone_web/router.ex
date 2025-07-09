defmodule BetZoneWeb.Router do
  use BetZoneWeb, :router

  import BetZoneWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BetZoneWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BetZoneWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/dashboard", DashboardLive, :index
    live "/basketball", OtherSportsLive, :basketball
    live "/tennis", OtherSportsLive, :tennis
    live "/rugby", OtherSportsLive, :rugby
    live "/volleyball", OtherSportsLive, :volleyball
    live "/hockey", OtherSportsLive, :hockey
    live "/admin_panel", AdminPanelLive, :index
    live "/super_panel", SuperPanelLive, :index

    get "/", UserSessionController, :new

    # User authentication routes
    live "/users/register", UserRegistrationLive, :new
    post "/users/log_in", UserSessionController, :create
    delete "/users/log_out", UserSessionController, :delete
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
