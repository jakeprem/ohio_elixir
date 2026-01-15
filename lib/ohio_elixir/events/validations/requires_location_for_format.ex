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
    status = Ash.Changeset.get_attribute(changeset, :status)

    if status == :published do
      validate_location_for_format(changeset)
    else
      :ok
    end
  end

  defp validate_location_for_format(changeset) do
    format = Ash.Changeset.get_attribute(changeset, :format)
    venue_id = Ash.Changeset.get_attribute(changeset, :venue_id)
    meeting_url = Ash.Changeset.get_attribute(changeset, :meeting_url)

    cond do
      format in [:in_person, :hybrid] and is_nil(venue_id) ->
        {:error, field: :venue_id, message: "#{format_name(format)} events require a venue"}

      format in [:online, :hybrid] and blank?(meeting_url) ->
        {:error,
         field: :meeting_url, message: "#{format_name(format)} events require a meeting URL"}

      true ->
        :ok
    end
  end

  defp format_name(:in_person), do: "In-person"
  defp format_name(:online), do: "Online"
  defp format_name(:hybrid), do: "Hybrid"

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false
end
