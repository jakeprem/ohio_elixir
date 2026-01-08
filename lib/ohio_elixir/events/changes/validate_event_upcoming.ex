defmodule OhioElixir.Events.Changes.ValidateEventUpcoming do
  @moduledoc """
  A change that validates the event being RSVPed to has not ended.

  This runs as a before_action hook because it needs access to the managed
  event relationship, which isn't available during the validation phase.

  RSVPs are allowed while the event is ongoing (after start time but before end time).
  If no end time is set, defaults to 2 hours after start time.
  """
  use Ash.Resource.Change

  # Default event duration when ends_at is not set (2 hours)
  @default_duration_hours 2

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case Ash.Changeset.get_attribute(changeset, :event_id) do
        nil ->
          Ash.Changeset.add_error(changeset, field: :event_id, message: "event_id is required")

        event_id ->
          validate_event_upcoming(changeset, event_id)
      end
    end)
  end

  defp validate_event_upcoming(changeset, event_id) do
    case OhioElixir.Events.get_event(event_id) do
      {:ok, event} ->
        rsvp_cutoff = event_rsvp_cutoff(event)

        if DateTime.compare(rsvp_cutoff, DateTime.utc_now()) == :gt do
          changeset
        else
          Ash.Changeset.add_error(changeset, field: :event_id, message: "event has already ended")
        end

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :event_id, message: "event not found")
    end
  end

  defp event_rsvp_cutoff(event) do
    event.ends_at || DateTime.add(event.starts_at, @default_duration_hours, :hour)
  end
end
