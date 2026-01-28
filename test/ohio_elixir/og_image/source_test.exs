defmodule OhioElixir.OGImage.SourceTest do
  use OhioElixir.DataCase

  alias OhioElixir.OGImage.Source
  alias OhioElixir.Events.Event

  describe "OGImage.Source for Event" do
    test "og_title returns event title" do
      event = build_event(title: "Test Event")
      assert Source.og_title(event) == "Test Event"
    end

    test "og_description returns short_description when present" do
      event = build_event(short_description: "Short desc", description: "Long desc")
      assert Source.og_description(event) == "Short desc"
    end

    test "og_description truncates description when no short_description" do
      long_desc = String.duplicate("a", 250)
      event = build_event(description: long_desc)
      result = Source.og_description(event)
      assert String.length(result) == 203
      assert String.ends_with?(result, "...")
    end

    test "og_description returns default when no descriptions" do
      event = build_event()
      assert Source.og_description(event) == "Join us for this Ohio Elixir event!"
    end

    test "og_type returns event" do
      event = build_event()
      assert Source.og_type(event) == "event"
    end

    test "og_image_params includes title and subtitle" do
      event = build_event(title: "My Event", format: :online)
      params = Source.og_image_params(event)

      assert params.title == "My Event"
      assert is_binary(params.subtitle)
    end

    test "subtitle shows Online for online events" do
      event = build_event(format: :online)
      %{subtitle: subtitle} = Source.og_image_params(event)
      assert subtitle =~ "Online"
    end

    test "subtitle shows Hybrid for hybrid events" do
      event = build_event(format: :hybrid)
      %{subtitle: subtitle} = Source.og_image_params(event)
      assert subtitle =~ "Hybrid"
    end

    test "subtitle shows venue name for in-person events" do
      venue = %{name: "Improving Columbus"}
      event = build_event(format: :in_person, venue: venue)
      %{subtitle: subtitle} = Source.og_image_params(event)
      assert subtitle =~ "Improving Columbus"
    end

    test "subtitle includes formatted date" do
      # Feb 3, 2026 at midnight UTC = Feb 2, 2026 7pm ET
      event = build_event(starts_at: ~U[2026-02-03 00:00:00Z], timezone: "America/New_York")
      %{subtitle: subtitle} = Source.og_image_params(event)
      assert subtitle =~ "February 2, 2026"
    end

    test "subtitle includes time with timezone abbreviation" do
      # Feb 3, 2026 at midnight UTC = Feb 2, 2026 7pm EST
      event = build_event(starts_at: ~U[2026-02-03 00:00:00Z], timezone: "America/New_York")
      %{subtitle: subtitle} = Source.og_image_params(event)
      assert subtitle =~ ~r/\d+:\d+ [AP]M EST/
    end
  end

  defp build_event(attrs \\ []) do
    defaults = %{
      title: "Default Event",
      description: nil,
      short_description: nil,
      format: :online,
      starts_at: ~U[2026-02-04 00:00:00Z],
      timezone: "America/New_York",
      venue: nil
    }

    struct(Event, Map.merge(defaults, Map.new(attrs)))
  end
end
