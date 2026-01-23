defmodule OhioElixirWeb.FeedController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events
  alias OhioElixir.Events.Event
  alias Atomex.{Feed, Entry}

def index(conn, _params) do
    events =
      Events.list_events!(
        %{visible_only: true, time_filter: :all},
        actor: nil,
        query: [limit: 50],
        load: [:venue]
      )

    feed = build_feed(conn, events)

    conn
    |> put_resp_content_type("application/atom+xml")
    |> put_resp_header(
      "cache-control",
      "public, max-age=900, stale-while-revalidate=3600, stale-if-error=86400"
    )
    |> put_resp_header("cdn-cache-control", "max-age=900")
    |> send_resp(200, feed)
  end

  def ics(conn, _params) do
    events =
      Events.list_events!(
        %{visible_only: true, time_filter: :upcoming},
        actor: nil,
        query: [limit: 100],
        load: [:venue]
      )

    ics_content = build_icalendar(conn, events)

    conn
    |> put_resp_content_type("text/calendar")
    |> put_resp_header(
      "cache-control",
      "public, max-age=900, stale-while-revalidate=3600"
    )
    |> put_resp_header("content-disposition", "inline; filename=\"ohio-elixir-events.ics\"")
    |> send_resp(200, ics_content)
  end

  defp build_feed(conn, events) do
    Feed.new(url(conn, ~p"/events"), feed_updated(events), "Ohio Elixir Events")
    |> Feed.author("Ohio Elixir")
    |> Feed.link(url(conn, ~p"/feed.xml"), rel: "self")
    |> Feed.link(url(conn, ~p"/events"), rel: "alternate")
    |> Feed.entries(Enum.map(events, &build_entry(conn, &1)))
    |> Feed.build()
    |> Atomex.generate_document()
  end

  defp build_entry(conn, event) do
    Entry.new("urn:uuid:#{event.id}", event.updated_at, event_title(event))
    |> Entry.link(url(conn, ~p"/events/#{event.id}"), rel: "alternate")
    |> Entry.published(event.inserted_at)
    |> maybe_add_summary(event)
    |> maybe_add_content(event)
    |> Entry.build()
  end

  defp event_title(event) do
    if Event.cancelled?(event), do: "[CANCELLED] #{event.title}", else: event.title
  end

  defp feed_updated([]), do: DateTime.utc_now()
  defp feed_updated(events), do: events |> Enum.map(& &1.updated_at) |> Enum.max(DateTime)

  defp maybe_add_summary(entry, %{short_description: desc})
       when is_binary(desc) and desc != "" do
    Entry.summary(entry, desc)
  end

  defp maybe_add_summary(entry, _), do: entry

  defp maybe_add_content(entry, event) do
    content = build_content(event)

    if content != "" do
      Entry.content(entry, content, type: "html")
    else
      entry
    end
  end

  defp build_content(event) do
    parts = [
      format_event_datetime(event),
      format_event_format(event),
      format_event_location(event),
      format_event_description(event)
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp format_event_datetime(event) do
    tz = event.timezone || "America/New_York"

    date = format_date(event.starts_at, tz)
    start_time = format_time(event.starts_at, tz)

    time_str =
      if event.ends_at do
        "#{start_time} - #{format_time(event.ends_at, tz)}"
      else
        start_time
      end

    tz_abbrev = timezone_abbrev(event.starts_at, tz)
    "<strong>When:</strong> #{date} at #{time_str} #{tz_abbrev}"
  end

  defp format_event_format(event) do
    format_label =
      case event.format do
        :in_person -> "In Person"
        :online -> "Online"
        :hybrid -> "Hybrid (In Person + Online)"
      end

    "<strong>Format:</strong> #{format_label}"
  end

  defp format_event_location(event) do
    venue = get_field(event, :venue)
    meeting_url = get_field(event, :meeting_url)

    cond do
      event.format in [:in_person, :hybrid] && venue ->
        address_parts =
          [:address_line_1, :city, :state]
          |> Enum.map(&get_field(venue, &1))
          |> Enum.reject(&is_nil/1)

        address = if address_parts != [], do: " - #{Enum.join(address_parts, ", ")}", else: ""
        "<strong>Location:</strong> #{get_field(venue, :name)}#{address}"

      event.format in [:online, :hybrid] && is_binary(meeting_url) ->
        "<strong>Meeting Link:</strong> #{meeting_url}"

      true ->
        nil
    end
  end

  defp format_event_description(%{description: desc}) when is_binary(desc) and desc != "" do
    "<strong>Details:</strong>\n#{desc}"
  end

  defp format_event_description(_), do: nil

  defp format_date(datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, local} -> Calendar.strftime(local, "%A, %B %-d, %Y")
      _ -> Calendar.strftime(datetime, "%A, %B %-d, %Y")
    end
  end

  defp format_time(datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, local} -> Calendar.strftime(local, "%-I:%M %p")
      _ -> Calendar.strftime(datetime, "%-I:%M %p")
    end
  end

  defp timezone_abbrev(datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, local} -> Calendar.strftime(local, "%Z")
      _ -> "UTC"
    end
  end

  # Safely access a field that may be Ash.ForbiddenField
  defp get_field(struct, field) when is_atom(field) do
    case Map.get(struct, field) do
      %Ash.ForbiddenField{} -> nil
      value -> value
    end
  end

  defp get_field(_struct, value), do: value

  # --- iCalendar generation ---

  defp build_icalendar(conn, events) do
    vevents = Enum.map(events, &build_vevent(conn, &1))

    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Ohio Elixir//ohioelixir.com//EN
    CALSCALE:GREGORIAN
    METHOD:PUBLISH
    X-WR-CALNAME:Ohio Elixir Events
    #{Enum.join(vevents, "\n")}
    END:VCALENDAR
    """
    |> String.trim()
  end

  defp build_vevent(conn, event) do
    uid = "event-#{event.id}@ohioelixir.com"
    dtstamp = ics_datetime(DateTime.utc_now())
    dtstart = ics_datetime(event.starts_at)
    dtend = ics_datetime(event.ends_at || DateTime.add(event.starts_at, 2, :hour))
    summary = ics_escape(ics_summary(event))
    description = ics_escape(ics_description(event))
    location = ics_escape(ics_location(event))
    event_url = url(conn, ~p"/events/#{event.id}")
    status = if event.cancelled, do: "CANCELLED", else: "CONFIRMED"

    lines =
      [
        "BEGIN:VEVENT",
        "UID:#{uid}",
        "DTSTAMP:#{dtstamp}",
        "DTSTART:#{dtstart}",
        "DTEND:#{dtend}",
        "SUMMARY:#{summary}",
        if(description, do: "DESCRIPTION:#{description}"),
        if(location, do: "LOCATION:#{location}"),
        "URL:#{event_url}",
        "STATUS:#{status}",
        "CLASS:PUBLIC",
        "END:VEVENT"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(lines, "\n")
  end

  defp ics_summary(event) do
    if event.cancelled, do: "[CANCELLED] #{event.title}", else: event.title
  end

  defp ics_description(event) do
    parts =
      [
        ics_format_label(event.format),
        get_field(event, :description)
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: nil, else: Enum.join(parts, "\n\n")
  end

  defp ics_location(event) do
    venue = get_field(event, :venue)

    cond do
      event.format in [:in_person, :hybrid] && venue ->
        [:name, :address_line_1, :city, :state]
        |> Enum.map(&get_field(venue, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.join(", ")

      event.format == :online ->
        "Online"

      event.format == :hybrid ->
        "Online (see event page for details)"

      true ->
        nil
    end
  end

  defp ics_format_label(:in_person), do: "In Person"
  defp ics_format_label(:online), do: "Online"
  defp ics_format_label(:hybrid), do: "Hybrid (In Person + Online)"

  defp ics_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp ics_escape(nil), do: nil

  defp ics_escape(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
    |> String.replace("\n", "\\n")
  end
end
