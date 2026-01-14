defmodule OhioElixirWeb.EventController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events

  plug OhioElixirWeb.Plugs.CacheControl

  def index(conn, params) do
    view = params["view"] || "upcoming"
    current_user = conn.assigns[:current_user]
    time_filter = if view == "past", do: :past, else: :upcoming

    events = Events.list_events!(%{time_filter: time_filter}, actor: current_user)

    render(conn, :index, events: events, current_view: view)
  end

  def show(conn, params) do
    id = params["id"]
    mode = params["mode"]
    current_user = conn.assigns[:current_user]

    case Events.get_event(id, load: [:venue, :rsvp_count, rsvps: [:user]], actor: current_user) do
      {:ok, event} ->
        existing_rsvp = get_existing_rsvp(current_user, id)

        render(conn, :show,
          event: event,
          existing_rsvp: existing_rsvp,
          mode: mode
        )

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/events")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Unable to load event")
        |> redirect(to: ~p"/events")
    end
  end

  def publish(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, event} <- Events.get_event(id, actor: current_user),
         {:ok, _event} <- Events.publish_event(event, actor: current_user) do
      conn
      |> put_flash(:info, "Event published successfully")
      |> redirect(to: ~p"/events/#{id}")
    else
      {:error, %Ash.Error.Forbidden{}} ->
        conn
        |> put_flash(:error, "You don't have permission to publish this event")
        |> redirect(to: ~p"/events/#{id}")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Unable to publish event")
        |> redirect(to: ~p"/events/#{id}")
    end
  end

  def cancel(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, event} <- Events.get_event(id, actor: current_user),
         {:ok, _event} <- Events.cancel_event(event, actor: current_user) do
      conn
      |> put_flash(:info, "Event cancelled")
      |> redirect(to: ~p"/events/#{id}")
    else
      {:error, %Ash.Error.Forbidden{}} ->
        conn
        |> put_flash(:error, "You don't have permission to cancel this event")
        |> redirect(to: ~p"/events/#{id}")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Unable to cancel event")
        |> redirect(to: ~p"/events/#{id}")
    end
  end

  defp get_existing_rsvp(nil, _event_id), do: nil

  defp get_existing_rsvp(user, event_id) do
    case Events.get_rsvp_by_user_and_event(user.id, event_id, actor: user) do
      {:ok, rsvp} -> rsvp
      _ -> nil
    end
  end
end
