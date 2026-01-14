defmodule OhioElixirWeb.AnalyticsController do
  @moduledoc """
  Proxy for GoatCounter analytics to bypass adblockers.

  Currently UNUSED - we're using direct GoatCounter integration instead.
  To enable: change data-goatcounter in root.html.heex from the full URL to "/gc/count"

  Request flow: User -> Cloudflare (proxy mode) -> Fly.io -> This controller -> GoatCounter

  We forward the original client IP and User-Agent so GoatCounter can do
  geolocation and unique visitor detection accurately.
  """
  use OhioElixirWeb, :controller

  # 100 requests per minute per IP should be plenty for normal browsing
  @rate_limit 100
  @rate_window :timer.minutes(1)

  def count(conn, params) do
    client_ip = client_ip(conn)

    # Silent drop if rate limited - we don't give feedback on analytics endpoints
    if rate_limit_allowed?("gc", client_ip) do
      forward_to_goatcounter(params, client_ip, user_agent(conn))
    end

    send_resp(conn, 204, "")
  end

  defp forward_to_goatcounter(params, client_ip, user_agent) do
    url = Application.get_env(:ohio_elixir, :goatcounter)[:url]

    Task.start(fn ->
      Req.get(url,
        params: params,
        headers: [
          {"user-agent", user_agent},
          {"x-forwarded-for", client_ip}
        ]
      )
    end)
  end

  defp rate_limit_allowed?(key, client_ip) do
    case OhioElixir.RateLimiter.hit("#{key}:#{client_ip}", @rate_window, @rate_limit) do
      {:allow, _count} -> true
      {:deny, _retry_after} -> false
    end
  end

  # Extracts the real client IP from proxy headers.
  # Cloudflare sets CF-Connecting-IP, Fly.io sets X-Forwarded-For.
  defp client_ip(conn) do
    get_req_header(conn, "cf-connecting-ip")
    |> List.first()
    |> Kernel.||(get_req_header(conn, "x-forwarded-for") |> List.first())
    |> Kernel.||(conn.remote_ip |> :inet.ntoa() |> to_string())
  end

  defp user_agent(conn) do
    get_req_header(conn, "user-agent") |> List.first() || ""
  end
end
