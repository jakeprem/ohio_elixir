defmodule OhioElixir.Events do
  use Ash.Domain,
    otp_app: :ohio_elixir,
    extensions: [AshAdmin.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  json_api do
    log_errors? true
  end

  resources do
    resource OhioElixir.Events.Venue do
      define :list_venues, action: :read
      define :get_venue, action: :read, get_by: [:id]
      define :create_venue, action: :create
      define :update_venue, action: :update
      define :destroy_venue, action: :destroy
    end

    resource OhioElixir.Events.Event do
      define :list_events, action: :read
      define :list_published_events, action: :list_published
      define :list_upcoming_events, action: :list_upcoming
      define :get_event, action: :read, get_by: [:id]
      define :create_event, action: :create
      define :update_event, action: :update
      define :publish_event, action: :publish
      define :cancel_event, action: :cancel
      define :destroy_event, action: :destroy
    end

    resource OhioElixir.Events.Rsvp do
      define :rsvp_to_event, action: :rsvp, args: [:event_id]
      define :guest_rsvp_to_event, action: :guest_rsvp, args: [:event_id, :email]
      define :get_rsvp_by_email_and_event, action: :get_by_email_and_event, args: [:email, :event_id]
      define :cancel_rsvp, action: :cancel
      define :mark_rsvp_attended, action: :mark_attended
      define :my_rsvps, action: :my_rsvps
    end
  end
end
