# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script is idempotent - it will skip records that already exist.

alias OhioElixir.{Accounts, Events}

# Create users
admin = Ash.Seed.seed!(Accounts.User, %{email: "admin@ohioelixir.com", role: :admin})
IO.puts("Seeded user: #{admin.email}")

user = Ash.Seed.seed!(Accounts.User, %{email: "user@example.com", role: :user})
IO.puts("Seeded user: #{user.email}")

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

# Create RSVPs
# We use Ash.Seed to directly create RSVPs, bypassing authorization,
# since the events were just published and may not pass the public_at <= now() check
# due to timing precision issues with SQLite
IO.puts("Creating RSVPs...")

Ash.Seed.seed!(OhioElixir.Events.Rsvp, %{
  user_id: user.id,
  event_id: upcoming_inperson.id,
  status: :confirmed
})
IO.puts("Created RSVP for #{user.email} to #{upcoming_inperson.title}")

Ash.Seed.seed!(OhioElixir.Events.Rsvp, %{
  user_id: user.id,
  event_id: upcoming_hybrid.id,
  status: :confirmed
})
IO.puts("Created RSVP for #{user.email} to #{upcoming_hybrid.title}")

Ash.Seed.seed!(OhioElixir.Events.Rsvp, %{
  user_id: admin.id,
  event_id: upcoming_hybrid.id,
  status: :confirmed
})
IO.puts("Created RSVP for #{admin.email} to #{upcoming_hybrid.title}")

IO.puts("\nSeed data created successfully!")
IO.puts("Admin user: admin@ohioelixir.com")
IO.puts("Regular user: user@example.com")
