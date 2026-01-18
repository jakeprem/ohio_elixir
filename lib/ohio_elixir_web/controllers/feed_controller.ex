defmodule OhioElixirWeb.FeedController do
  use OhioElixirWeb, :controller

  alias OhioElixir.Events
  alias Atomex.{Feed, Entry}

  def index(conn, _params) do
    events =
      Events.list_events!(
        %{visible_only: true, time_filter: :all},
        actor: nil,
        query: [limit: 50]
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

  defp event_title(%{status: :cancelled, title: title}), do: "[CANCELLED] #{title}"
  defp event_title(%{title: title}), do: title

  defp feed_updated([]), do: DateTime.utc_now()
  defp feed_updated(events), do: events |> Enum.map(& &1.updated_at) |> Enum.max(DateTime)

  defp maybe_add_summary(entry, %{short_description: desc})
       when is_binary(desc) and desc != "" do
    Entry.summary(entry, desc)
  end

  defp maybe_add_summary(entry, _), do: entry

  defp maybe_add_content(entry, %{description: desc}) when is_binary(desc) and desc != "" do
    Entry.content(entry, desc, type: "text")
  end

  defp maybe_add_content(entry, _), do: entry
end
