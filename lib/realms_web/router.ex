defmodule RealmsWeb.Router do
  use RealmsWeb, :router

  import RealmsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RealmsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug RealmsWeb.PlayerSession
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RealmsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :default,
      on_mount: [{RealmsWeb.UserAuth, :require_authenticated}, RealmsWeb.PlayerSession] do
      live "/", GameLive
      live "/players", PlayerManagementLive
    end

    post "/players/:id/play", PlayerSessionController, :play_as
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:realms, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RealmsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", RealmsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{RealmsWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", RealmsWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{RealmsWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      # Magic link confirmation temporarily disabled
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
