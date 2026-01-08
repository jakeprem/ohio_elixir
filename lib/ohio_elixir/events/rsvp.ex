defmodule OhioElixir.Events.Rsvp do
  use Ash.Resource,
    otp_app: :ohio_elixir,
    domain: OhioElixir.Events,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource, AshJsonApi.Resource]

  sqlite do
    table "event_rsvps"
    repo OhioElixir.Repo
  end

  json_api do
    type "rsvp"

    routes do
      base "/rsvps"

      index :my_rsvps, route: "/mine"
      post :rsvp
      patch :cancel, route: "/:id/cancel"
      patch :mark_attended, route: "/:id/attended"
    end
  end

  actions do
    defaults [:read]

    create :rsvp do
      description "RSVP to an event as an authenticated user."
      primary? true
      accept [:notes, :attendance_mode]

      argument :event_id, :uuid, allow_nil?: false

      upsert? true
      upsert_identity :unique_user_event
      upsert_fields [:status, :attendance_mode, :notes]

      change relate_actor(:user)
      change manage_relationship(:event_id, :event, type: :append)
      change set_attribute(:status, :confirmed)
    end

    create :guest_rsvp do
      description "RSVP as a guest with email address"
      accept [:notes, :attendance_mode]

      argument :event_id, :uuid, allow_nil?: false
      argument :email, :ci_string, allow_nil?: false

      upsert? true
      upsert_identity :unique_user_event
      upsert_fields [:status, :attendance_mode, :notes]

      change {OhioElixir.Events.Changes.FindOrCreateUserByEmail, []}
      change manage_relationship(:event_id, :event, type: :append)
      change set_attribute(:status, :confirmed)
    end

    update :update do
      description "Update an RSVP (e.g., change attendance mode)."
      primary? true
      accept [:attendance_mode, :notes]
    end

    update :cancel do
      description "Cancel an RSVP."
      change set_attribute(:status, :cancelled)
    end

    update :mark_attended do
      description "Mark an RSVP as attended (admin only)."
      change set_attribute(:attended, true)
    end

    read :my_rsvps do
      description "List the current user's RSVPs."
      filter expr(user_id == ^actor(:id))
      prepare build(load: [:event])
    end

    read :get_by_user_and_event do
      description "Get an RSVP by user ID and event ID"
      argument :user_id, :uuid, allow_nil?: false
      argument :event_id, :uuid, allow_nil?: false
      get? true
      filter expr(user_id == ^arg(:user_id) and event_id == ^arg(:event_id))
    end
  end

  policies do
    # Users can view their own RSVPs
    policy action(:my_rsvps) do
      authorize_if actor_present()
    end

    # Get RSVP by user and event - for checking existing RSVPs
    policy action(:get_by_user_and_event) do
      authorize_if always()
    end

    # General read - admin can read all, users can read own
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if relates_to_actor_via(:user)
    end

    # Create RSVP - any logged-in user
    policy action(:rsvp) do
      authorize_if actor_present()
    end

    # Guest RSVP - public (no actor required)
    policy action(:guest_rsvp) do
      authorize_if always()
    end

    # Update - admin or own RSVP
    policy action(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if relates_to_actor_via(:user)
    end

    # Cancel - admin or own RSVP
    policy action(:cancel) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if relates_to_actor_via(:user)
    end

    # Mark attended - admin only
    policy action(:mark_attended) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      default :confirmed
      public? true
      constraints one_of: [:confirmed, :cancelled, :waitlisted]
    end

    attribute :notes, :string, public?: true, constraints: [max_length: 500]
    attribute :attended, :boolean, public?: true, default: false
    attribute :attendance_mode, :atom, public?: true, constraints: [one_of: [:in_person, :online]]

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :event, OhioElixir.Events.Event do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, OhioElixir.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_user_event, [:user_id, :event_id]
  end
end
