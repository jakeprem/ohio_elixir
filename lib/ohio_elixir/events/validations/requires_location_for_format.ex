defmodule OhioElixir.Events.Validations.RequiresLocationForFormat do
  @moduledoc """
  Validates that events have the appropriate location fields set based on format.

  - In-person events require a venue
  - Online events require a meeting URL
  - Hybrid events require both venue and meeting URL
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    format = Ash.Changeset.get_attribute(changeset, :format)
    venue_id = Ash.Changeset.get_attribute(changeset, :venue_id)
    meeting_url = Ash.Changeset.get_attribute(changeset, :meeting_url)

    case format do
      :in_person when is_nil(venue_id) ->
        {:error, field: :venue_id, message: "In-person events require a venue"}

      :online when is_nil(meeting_url) or meeting_url == "" ->
        {:error, field: :meeting_url, message: "Online events require a meeting URL"}

      :hybrid when is_nil(venue_id) ->
        {:error, field: :venue_id, message: "Hybrid events require a venue"}

      :hybrid when is_nil(meeting_url) or meeting_url == "" ->
        {:error, field: :meeting_url, message: "Hybrid events require a meeting URL"}

      _ ->
        :ok
    end
  end
end
