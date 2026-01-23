defmodule OhioElixirWeb.FeedControllerTest do
  use OhioElixirWeb.ConnCase

  alias OhioElixir.Events
  alias OhioElixir.Accounts

  describe "GET /feed.xml" do
    test "returns atom feed with correct content type", %{conn: conn} do
      conn = get(conn, ~p"/feed.xml")

      assert get_resp_header(conn, "content-type") |> hd() =~ "application/atom+xml"
      assert response(conn, 200) =~ ~s(<?xml version="1.0")
      assert response(conn, 200) =~ "<feed xmlns="
    end

    test "includes published events", %{conn: conn} do
      event = create_published_event!("Test Published Event")

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ "Test Published Event"
      assert body =~ event.id
    end

    test "excludes draft events", %{conn: conn} do
      _draft = create_draft_event!("Draft Event Title")

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      refute body =~ "Draft Event Title"
    end

    test "marks cancelled events with prefix", %{conn: conn} do
      event = create_cancelled_event!("Cancelled Meetup")

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ "[CANCELLED] Cancelled Meetup"
      assert body =~ event.id
    end

    test "includes feed metadata", %{conn: conn} do
      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ "<title>Ohio Elixir Events</title>"
      assert body =~ "<author>"
      assert body =~ "Ohio Elixir"
    end

    test "includes short_description as summary when present", %{conn: conn} do
      _event =
        create_published_event!("Event With Summary",
          short_description: "A short description for the summary"
        )

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ "A short description for the summary"
    end
  end

  describe "GET /feed.ics" do
    test "returns icalendar feed with correct content type", %{conn: conn} do
      conn = get(conn, ~p"/feed.ics")

      assert get_resp_header(conn, "content-type") |> hd() =~ "text/calendar"
      assert response(conn, 200) =~ "BEGIN:VCALENDAR"
      assert response(conn, 200) =~ "END:VCALENDAR"
    end

    test "includes upcoming published events", %{conn: conn} do
      event = create_published_event!("Upcoming ICS Event")

      conn = get(conn, ~p"/feed.ics")
      body = response(conn, 200)

      assert body =~ "BEGIN:VEVENT"
      assert body =~ "Upcoming ICS Event"
      assert body =~ event.id
    end

    test "excludes draft events", %{conn: conn} do
      _draft = create_draft_event!("Draft ICS Event")

      conn = get(conn, ~p"/feed.ics")
      body = response(conn, 200)

      refute body =~ "Draft ICS Event"
    end

    test "marks cancelled events with CANCELLED status", %{conn: conn} do
      _event = create_cancelled_event!("Cancelled ICS Event")

      conn = get(conn, ~p"/feed.ics")
      body = response(conn, 200)

      assert body =~ "[CANCELLED] Cancelled ICS Event"
      assert body =~ "STATUS:CANCELLED"
    end

    test "includes calendar metadata", %{conn: conn} do
      conn = get(conn, ~p"/feed.ics")
      body = response(conn, 200)

      assert body =~ "VERSION:2.0"
      assert body =~ "PRODID:-//Ohio Elixir"
      assert body =~ "X-WR-CALNAME:Ohio Elixir Events"
    end

    test "does not expose meeting URLs", %{conn: conn} do
      _event = create_published_event!("Online Event Test")

      conn = get(conn, ~p"/feed.ics")
      body = response(conn, 200)

      refute body =~ "example.com/meeting"
      assert body =~ "LOCATION:Online"
    end
  end

  defp create_admin_user! do
    Ash.Seed.seed!(Accounts.User, %{
      email: "admin-#{System.unique_integer()}@test.com",
      role: :admin
    })
  end

  defp create_draft_event!(title, opts \\ []) do
    admin = create_admin_user!()

    Events.create_event!(
      %{
        title: title,
        starts_at: DateTime.add(DateTime.utc_now(), 7, :day),
        format: :online,
        meeting_url: "https://example.com/meeting",
        description: Keyword.get(opts, :description),
        short_description: Keyword.get(opts, :short_description)
      },
      actor: admin
    )
  end

  defp create_published_event!(title, opts \\ []) do
    admin = create_admin_user!()
    # Set public_at to 1 minute ago to avoid timing issues with SQLite's now()
    public_at = DateTime.add(DateTime.utc_now(), -60, :second)

    Ash.Seed.seed!(OhioElixir.Events.Event, %{
      title: title,
      starts_at: DateTime.add(DateTime.utc_now(), 7, :day),
      format: :online,
      meeting_url: "https://example.com/meeting",
      description: Keyword.get(opts, :description),
      short_description: Keyword.get(opts, :short_description),
      public_at: public_at,
      cancelled: false,
      created_by_id: admin.id
    })
  end

  defp create_cancelled_event!(title, opts \\ []) do
    admin = create_admin_user!()
    # Set public_at to 1 minute ago to avoid timing issues with SQLite's now()
    public_at = DateTime.add(DateTime.utc_now(), -60, :second)

    Ash.Seed.seed!(OhioElixir.Events.Event, %{
      title: title,
      starts_at: DateTime.add(DateTime.utc_now(), 7, :day),
      format: :online,
      meeting_url: "https://example.com/meeting",
      description: Keyword.get(opts, :description),
      short_description: Keyword.get(opts, :short_description),
      public_at: public_at,
      cancelled: true,
      created_by_id: admin.id
    })
  end
end
