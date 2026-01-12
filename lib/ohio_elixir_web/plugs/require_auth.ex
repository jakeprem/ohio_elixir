defmodule OhioElixirWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that requires an authenticated user.
  Redirects to sign-in page if no user is present.

  Based on the pattern from Phoenix's `phx.gen.auth` generator.
  """
  import Plug.Conn
  import Phoenix.Controller
  use OhioElixirWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be signed in to access this page")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/sign-in")
      |> halt()
    end
  end

  # Store return path for GET requests so user can be redirected back after login
  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
