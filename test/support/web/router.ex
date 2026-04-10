defmodule ErrorTracker.Test.Router do
  use Phoenix.Router
  use ErrorTracker.Web, :router

  import Phoenix.LiveView.Router

  scope "/" do
    scope "/dashboard" do
      error_tracker_dashboard "/", csp_nonce_assign_key: :custom_csp_nonce
    end
  end
end
