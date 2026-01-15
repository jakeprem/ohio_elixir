defmodule OhioElixirWeb.PageController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events

  plug OhioElixirWeb.Plugs.CacheControl

  def home(conn, _params) do
    current_user = conn.assigns[:current_user]

    next_event =
      case Events.list_events!(%{visible_only: true, time_filter: :upcoming},
             actor: current_user,
             query: [limit: 1]
           ) do
        [event] -> event
        [] -> nil
      end

    render(conn, :home, next_event: next_event)
  end
end
