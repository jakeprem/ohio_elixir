defmodule OhioElixirWeb.PageController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events

  plug OhioElixirWeb.Plugs.CacheControl

  def home(conn, _params) do
    current_user = conn.assigns[:current_user]
    upcoming_events = Events.list_upcoming_events!(actor: current_user)
    render(conn, :home, upcoming_events: upcoming_events)
  end
end
