defmodule ErrorTracker.Test.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias ErrorTracker.Test.Endpoint

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn

      # The default endpoint for testing
      @endpoint ErrorTracker.Test.Endpoint
    end
  end

  setup do
    Sandbox.checkout(Application.fetch_env!(:error_tracker, :repo))

    Application.put_env(:error_tracker, Endpoint,
      live_view: [signing_salt: "GKUFNB6eIphYPACj"],
      secret_key_base: "zYE/3XXAfj3yGwtxFW7GEVA2uESGoeKG4HIhuwEAB9Sq2HfUar9xzSHpKXiiqh+T",
      render_errors: [formats: [html: ErrorTracker.Test.ErrorView], layout: false, log: :debug],
      debug_errors: false
    )

    start_supervised!(Endpoint)

    [conn: Phoenix.ConnTest.build_conn()]
  end
end
