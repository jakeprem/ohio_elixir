# OG Images with Talks

Design notes for extending OG image generation when talks are added to events.

## Current State

Events generate OG images with:
- **Title**: Event title
- **Subtitle**: `Location · Date · Time TZ` (e.g., "Online · February 3, 2026 · 7:00 PM ET")
- **Footer**: `www.ohioelixir.com`

## Future: Events with Talks

### Event Page OG Image

**Single talk on event:** Promote the talk to the main title
- **Title**: Talk title (e.g., "Building with Tidewave and Claude Code")
- **Subtitle**: `Ohio Elixir · February 3, 2026 · 7:00 PM ET`
- **Footer**: Could move location (Online/Hybrid/Venue) here if needed

**Multiple talks:** Show first/featured talk, or use generic framing
- **Title**: First talk title, or "February Meetup"
- **Subtitle**: Could list speakers: `Jake Prem, Jane Doe · February 3, 2026`
- Alternative: `2 Talks · February 3, 2026 · 7:00 PM ET`

### Talk Page OG Image

Each talk gets its own shareable URL (`/events/:event_id/talks/:talk_id`) with custom OG:
- **Title**: Talk title
- **Subtitle**: `Speaker Name · Ohio Elixir · February 3, 2026`

This lets speakers share their specific talk link with a personalized preview.

## Implementation Notes

### Protocol Extension

Add `OGImage.Source` implementation for `Talk`:

```elixir
defimpl OhioElixir.OGImage.Source, for: OhioElixir.Events.Talk do
  def og_title(talk), do: talk.title

  def og_description(talk) do
    talk.description || talk.event.short_description || "Join us for this Ohio Elixir talk!"
  end

  def og_image_params(talk) do
    %{
      title: talk.title,
      subtitle: build_subtitle(talk)
    }
  end

  def og_type(_talk), do: "event"

  defp build_subtitle(talk) do
    # Requires event to be loaded
    event = talk.event
    {date, time} = format_datetime(event.starts_at, event.timezone)

    [talk.speaker_name, "Ohio Elixir", date]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end
end
```

### Event OG with Single Talk

Update the Event implementation to detect and delegate:

```elixir
def og_title(event) do
  case single_talk(event) do
    nil -> event.title
    talk -> talk.title
  end
end

defp single_talk(%{talks: [talk]}), do: talk
defp single_talk(_), do: nil
```

### Loading Considerations

- Talk OG requires `event` to be loaded for date/time
- SQLite makes lazy loading cheap, but explicit loading is cleaner
- CDN caching means the DB hit only happens on cache miss (rare after first share)

## Design Decisions to Make Later

1. Should multiple talks show speaker names or talk count in subtitle?
2. Should talk pages be nested (`/events/:id/talks/:id`) or flat (`/talks/:id`)?
3. Should we add speaker photos to talk OG images? (requires TSX changes)
