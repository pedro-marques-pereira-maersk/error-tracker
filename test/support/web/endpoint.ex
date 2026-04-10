defmodule ErrorTracker.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :error_tracker

  socket "/live", Phoenix.LiveView.Socket, log: false

  plug :set_csp
  plug ErrorTracker.Test.Router

  defp set_csp(conn, _opts) do
    nonce = 10 |> :crypto.strong_rand_bytes() |> Base.encode64()

    policies = [
      "script-src 'self' 'nonce-#{nonce}';",
      "style-src 'self' 'nonce-#{nonce}';"
    ]

    conn
    |> Plug.Conn.assign(:custom_csp_nonce, "#{nonce}")
    |> Plug.Conn.put_resp_header("content-security-policy", Enum.join(policies, " "))
  end
end
