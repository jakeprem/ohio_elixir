# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script is idempotent - it will skip records that already exist.

alias OhioElixir.{Accounts, Events}

# Helper to get or create a user
defmodule Seeds do
  def get_or_create_user(email, role) do
    require Ash.Query

    case Accounts.User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        user =
          Accounts.User
          |> Ash.Changeset.for_create(:seed, %{email: email, role: role})
          |> Ash.create!(authorize?: false)

        IO.puts("Created user: #{user.email}")
        user

      user ->
        IO.puts("User already exists: #{user.email}")
        user
    end
  end
end

# Create users
admin = Seeds.get_or_create_user("admin@ohioelixir.org", :admin)
user = Seeds.get_or_create_user("user@example.com", :user)

# Create venues
improving_columbus =
  Events.create_venue!(
    %{
      name: "Improving Columbus",
      address_line_1: "8800 Lyra Dr",
      address_line_2: "Suite 400",
      city: "Columbus",
      state: "OH",
      postal_code: "43240",
      notes:
        "Free parking available. Enter through the main lobby and take the elevator to the 4th floor.",
      website_url: "https://improving.com"
    },
    actor: admin
  )

IO.puts("Created venue: #{improving_columbus.name}")

library =
  Events.create_venue!(
    %{
      name: "Columbus Metropolitan Library - Main Branch",
      address_line_1: "96 S Grant Ave",
      city: "Columbus",
      state: "OH",
      postal_code: "43215",
      notes: "Meeting rooms on the 2nd floor. Parking garage across the street.",
      website_url: "https://www.columbuslibrary.org"
    },
    actor: admin
  )

IO.puts("Created venue: #{library.name}")

# Create events
# Past event
past_event =
  Events.create_event!(
    %{
      title: "November Meetup: Intro to LiveView",
      description: """
      Join us for an introduction to Phoenix LiveView! We'll cover the basics of building
      real-time, interactive web applications without writing JavaScript.

      Topics:
      - LiveView fundamentals
      - Handling events
      - Live navigation
      - Real-world examples
      """,
      format: :hybrid,
      starts_at: DateTime.add(DateTime.utc_now(), -30, :day),
      ends_at: DateTime.add(DateTime.utc_now(), -30, :day) |> DateTime.add(2, :hour),
      venue_id: improving_columbus.id,
      meeting_url: "https://zoom.us/j/example123"
    },
    actor: admin
  )

Events.publish_event!(past_event, actor: admin)
IO.puts("Created past event: #{past_event.title}")

# Upcoming in-person event
upcoming_inperson =
  Events.create_event!(
    %{
      title: "January Meetup: Ash Framework Deep Dive",
      description: """
      This month we're diving deep into the Ash Framework! Learn how to build
      robust, maintainable Elixir applications with Ash.

      Topics:
      - Resources and domains
      - Actions and changesets
      - Policies and authorization
      - Building APIs with AshJsonApi

      Pizza and drinks will be provided!
      """,
      format: :in_person,
      starts_at: DateTime.add(DateTime.utc_now(), 14, :day) |> DateTime.truncate(:second),
      ends_at:
        DateTime.add(DateTime.utc_now(), 14, :day)
        |> DateTime.add(2, :hour)
        |> DateTime.truncate(:second),
      venue_id: improving_columbus.id
    },
    actor: admin
  )

Events.publish_event!(upcoming_inperson, actor: admin)
IO.puts("Created upcoming event: #{upcoming_inperson.title}")

# Upcoming hybrid event
upcoming_hybrid =
  Events.create_event!(
    %{
      title: "February Meetup: OTP and Fault Tolerance",
      description: """
      Learn about OTP patterns and building fault-tolerant systems in Elixir.

      Topics:
      - GenServer and Supervisors
      - Supervision trees
      - Error handling strategies
      - Real-world patterns

      This is a hybrid event - join us in person or online!
      """,
      format: :hybrid,
      starts_at: DateTime.add(DateTime.utc_now(), 45, :day) |> DateTime.truncate(:second),
      ends_at:
        DateTime.add(DateTime.utc_now(), 45, :day)
        |> DateTime.add(2, :hour)
        |> DateTime.truncate(:second),
      venue_id: library.id,
      meeting_url: "https://meet.google.com/ohio-elixir-feb"
    },
    actor: admin
  )

Events.publish_event!(upcoming_hybrid, actor: admin)
IO.puts("Created upcoming event: #{upcoming_hybrid.title}")

# Create RSVPs - use the event structs directly since they have IDs
IO.puts("Creating RSVPs...")
IO.puts("upcoming_inperson.id = #{inspect(upcoming_inperson.id)}")
IO.puts("upcoming_hybrid.id = #{inspect(upcoming_hybrid.id)}")

if upcoming_inperson.id do
  Events.rsvp_to_event!(upcoming_inperson.id, actor: user)
  IO.puts("Created RSVP for #{user.email} to #{upcoming_inperson.title}")
end

if upcoming_hybrid.id do
  Events.rsvp_to_event!(upcoming_hybrid.id, actor: user)
  IO.puts("Created RSVP for #{user.email} to #{upcoming_hybrid.title}")

  Events.rsvp_to_event!(upcoming_hybrid.id, actor: admin)
  IO.puts("Created RSVP for #{admin.email} to #{upcoming_hybrid.title}")
end

IO.puts("\nSeed data created successfully!")
IO.puts("Admin user: admin@ohioelixir.org")
IO.puts("Regular user: user@example.com")
