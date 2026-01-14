defmodule OhioElixir.Events.Changes.ValidateEventUpcoming do
  @moduledoc """
  A change that validates the event being RSVPed to has not ended.

  This runs as a before_action hook because it needs access to the managed
  event relationship, which isn't available during the validation phase.

  Uses the `rsvps_open?` calculation on Event to determine eligibility.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      # Check argument first (used by rsvp action), then attribute (used by guest_rsvp)
      event_id =
        Ash.Changeset.get_argument(changeset, :event_id) ||
          Ash.Changeset.get_attribute(changeset, :event_id)

      case event_id do
        nil ->
          Ash.Changeset.add_error(changeset, field: :event_id, message: "event_id is required")

        event_id ->
          validate_event_upcoming(changeset, event_id)
      end
    end)
  end

  defp validate_event_upcoming(changeset, event_id) do
    case OhioElixir.Events.get_event(event_id, load: [:rsvps_open?]) do
      {:ok, event} ->
        if event.rsvps_open? do
          changeset
        else
          Ash.Changeset.add_error(changeset, field: :event_id, message: "event has already ended")
        end

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :event_id, message: "event not found")
    end
  end
end
