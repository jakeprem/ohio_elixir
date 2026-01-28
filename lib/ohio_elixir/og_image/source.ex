defprotocol OhioElixir.OGImage.Source do
  @moduledoc """
  Protocol for extracting Open Graph metadata from domain structs.

  Implement this protocol for any struct that should have custom OG tags.
  The protocol provides all the data needed to populate OG meta tags.
  """

  @doc "Returns the OG title for social sharing"
  @spec og_title(t) :: String.t()
  def og_title(source)

  @doc "Returns the OG description for social sharing"
  @spec og_description(t) :: String.t()
  def og_description(source)

  @doc "Returns params for building the dynamic OG image URL"
  @spec og_image_params(t) :: map()
  def og_image_params(source)

  @doc "Returns the OG type (website, event, article, etc.)"
  @spec og_type(t) :: String.t()
  def og_type(source)
end

defimpl OhioElixir.OGImage.Source, for: OhioElixir.Events.Event do
  @doc """
  OG implementation for events.

  Generates smart subtitles like:
  - "January 15, 2026 · Online"
  - "January 15, 2026 · Improving Columbus"
  - "January 15, 2026 · Hybrid"
  """

  def og_title(event), do: event.title

  def og_description(event) do
    cond do
      has_content?(event.short_description) ->
        event.short_description

      has_content?(event.description) ->
        event.description
        |> String.slice(0, 200)
        |> then(fn desc ->
          if String.length(event.description) > 200, do: desc <> "...", else: desc
        end)

      true ->
        "Join us for this Ohio Elixir event!"
    end
  end

  def og_image_params(event) do
    %{
      title: event.title,
      subtitle: build_subtitle(event)
    }
  end

  def og_type(_event), do: "event"

  # Private helpers

  defp build_subtitle(event) do
    {date, time} = format_datetime(event.starts_at, event.timezone)
    location = format_location(event)

    [location, date, time]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp format_datetime(starts_at, timezone) do
    case DateTime.shift_zone(starts_at, timezone) do
      {:ok, local_dt} ->
        date = Calendar.strftime(local_dt, "%B %-d, %Y")
        time = Calendar.strftime(local_dt, "%-I:%M %p %Z")
        {date, time}

      {:error, _} ->
        {Calendar.strftime(starts_at, "%B %-d, %Y"), nil}
    end
  end

  defp format_location(event) do
    case event.format do
      :online -> "Online"
      :hybrid -> "Hybrid"
      :in_person -> venue_name(event) || "In Person"
    end
  end

  defp venue_name(%{venue: %{name: name}}) when is_binary(name), do: name
  defp venue_name(_), do: nil

  defp has_content?(nil), do: false
  defp has_content?(""), do: false
  defp has_content?(_), do: true
end
