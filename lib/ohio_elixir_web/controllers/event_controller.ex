defmodule OhioElixirWeb.EventController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events

  plug OhioElixirWeb.Plugs.CacheControl

  def show(conn, params) do
    id = params["id"]
    mode = params["mode"]
    current_user = conn.assigns[:current_user]

    case Events.get_event(id, load: [:venue, :rsvp_count]) do
      {:ok, event} ->
        existing_rsvp = get_existing_rsvp(current_user, id)

        render(conn, :show,
          event: event,
          existing_rsvp: existing_rsvp,
          current_user: current_user,
          mode: mode
        )

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Unable to load event")
        |> redirect(to: ~p"/")
    end
  end

  defp get_existing_rsvp(nil, _event_id), do: nil

  defp get_existing_rsvp(user, event_id) do
    case Events.get_rsvp_by_user_and_event(user.id, event_id) do
      {:ok, rsvp} -> rsvp
      _ -> nil
    end
  end
end
