defmodule OhioElixirWeb.PageController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events

  plug OhioElixirWeb.Plugs.CacheControl

  def home(conn, _params) do
    upcoming_events = Events.list_upcoming_events!(load: [:venue, :rsvp_count])
    render(conn, :home, upcoming_events: upcoming_events)
  end
end
