defmodule OhioElixirWeb.EventController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    case Events.get_event(id, load: [:venue, :rsvp_count]) do
      {:ok, event} ->
        existing_rsvp =
          if current_user do
            case Events.get_rsvp_by_email_and_event(current_user.email, id) do
              {:ok, rsvp} -> rsvp
              _ -> nil
            end
          else
            nil
          end

        render(conn, :show, event: event, existing_rsvp: existing_rsvp)

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
end
