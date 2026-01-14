defmodule OhioElixir.Events.Changes.SetDefaultAttendanceMode do
  @moduledoc """
  Sets the default attendance_mode based on the event's format.

  - in_person events → :in_person
  - online events → :online
  - hybrid events → :online (default)
  """
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    # Only set default if attendance_mode not already provided
    if Ash.Changeset.get_attribute(changeset, :attendance_mode) do
      changeset
    else
      Ash.Changeset.before_action(changeset, fn changeset ->
        event_id =
          Ash.Changeset.get_argument(changeset, :event_id) ||
            Ash.Changeset.get_attribute(changeset, :event_id)

        case event_id do
          nil -> changeset
          event_id -> set_default_from_event(changeset, event_id)
        end
      end)
    end
  end

  defp set_default_from_event(changeset, event_id) do
    case OhioElixir.Events.get_event(event_id) do
      {:ok, event} ->
        default_mode = default_mode_for_format(event.format)
        Ash.Changeset.force_change_attribute(changeset, :attendance_mode, default_mode)

      {:error, _} ->
        changeset
    end
  end

  defp default_mode_for_format(:in_person), do: :in_person
  defp default_mode_for_format(:online), do: :online
  defp default_mode_for_format(:hybrid), do: :online
  defp default_mode_for_format(_), do: :online
end
