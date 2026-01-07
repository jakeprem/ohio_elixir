defmodule OhioElixirWeb.Plugs.CacheControl do
  @moduledoc """
  A plug for setting cache control headers on responses.

  For authenticated users, sets `private, no-store` to prevent caching of
  personalized content. For anonymous users, sets public caching headers
  suitable for CDN caching (e.g., Cloudflare).

  ## Usage

      plug OhioElixirWeb.Plugs.CacheControl

  Or with custom options:

      plug OhioElixirWeb.Plugs.CacheControl,
        max_age: 600,
        stale_while_revalidate: 3600
  """
  import Plug.Conn

  @default_max_age 300
  @default_stale_while_revalidate 86_400
  @default_stale_if_error 604_800

  def init(opts) do
    %{
      max_age: Keyword.get(opts, :max_age, @default_max_age),
      stale_while_revalidate:
        Keyword.get(opts, :stale_while_revalidate, @default_stale_while_revalidate),
      stale_if_error: Keyword.get(opts, :stale_if_error, @default_stale_if_error)
    }
  end

  def call(conn, opts) do
    cache_control =
      if conn.assigns[:current_user] do
        "private, no-cache"
      else
        "public, max-age=#{opts.max_age}, stale-while-revalidate=#{opts.stale_while_revalidate}, stale-if-error=#{opts.stale_if_error}"
      end

    conn
    |> put_resp_header("cache-control", cache_control)
    |> put_resp_header("vary", "Cookie")
  end
end
