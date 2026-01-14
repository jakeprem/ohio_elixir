defmodule OhioElixir.Events.Event do
  use Ash.Resource,
    otp_app: :ohio_elixir,
    domain: OhioElixir.Events,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource, AshJsonApi.Resource],
    primary_read_warning?: false

  @visible_event_statuses [:published, :cancelled]

  sqlite do
    table "events"
    repo OhioElixir.Repo
  end

  json_api do
    type "event"

    routes do
      base "/events"

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
      patch :publish, route: "/:id/publish"
      patch :cancel, route: "/:id/cancel"
    end
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      argument :visible_only, :boolean, default: false
      argument :time_filter, :atom do
        constraints one_of: [:all, :upcoming, :past]
        default :all
      end

      prepare build(filter: expr(visible?)) do
        where argument_equals(:visible_only, true)
      end

      prepare build(filter: expr(starts_at > now()), sort: [starts_at: :asc]) do
        where argument_equals(:time_filter, :upcoming)
      end

      prepare build(filter: expr(starts_at <= now()), sort: [starts_at: :desc]) do
        where argument_equals(:time_filter, :past)
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*
      validate {OhioElixir.Events.Validations.RequiresLocationForFormat, []}
    end

    create :create do
      description "Create a new event in draft status."
      primary? true

      accept [
        :title,
        :description,
        :short_description,
        :format,
        :starts_at,
        :ends_at,
        :timezone,
        :meeting_url,
        :capacity,
        :venue_id
      ]

      change relate_actor(:created_by)
      change set_attribute(:status, :draft)
    end

    update :publish do
      description "Publish a draft event to make it publicly visible."
      require_atomic? false

      change set_attribute(:status, :published)

      validate present([:title, :starts_at])
      validate {OhioElixir.Events.Validations.RequiresLocationForFormat, []}
    end

    update :cancel do
      description "Cancel an event."
      change set_attribute(:status, :cancelled)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if expr(visible?)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  field_policies do
    field_policy :* do
      authorize_if always()
    end

    field_policy :meeting_url do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if expr(exists(rsvps, user_id == ^actor(:id) and status == :confirmed))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :description, :string, public?: true, constraints: [max_length: 10_000]
    attribute :short_description, :string, public?: true, constraints: [max_length: 300]

    attribute :status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :published, :cancelled]
    end

    attribute :format, :atom do
      allow_nil? false
      default :in_person
      public? true
      constraints one_of: [:in_person, :online, :hybrid]
    end

    attribute :starts_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :ends_at, :utc_datetime, public?: true

    attribute :timezone, :string do
      allow_nil? false
      default "America/New_York"
      public? true
    end

    attribute :meeting_url, :string, public?: true
    attribute :capacity, :integer, public?: true, constraints: [min: 1]

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :created_by, OhioElixir.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :venue, OhioElixir.Events.Venue do
      allow_nil? true
      public? true
      attribute_writable? true
    end

    has_many :rsvps, OhioElixir.Events.Rsvp
  end

  calculations do
    calculate :rsvp_count,
              :integer,
              expr(
                fragment(
                  "(SELECT COUNT(*) FROM event_rsvps WHERE event_id = ? AND status = 'confirmed')",
                  id
                )
              )

    calculate :visible?, :boolean, expr(status in @visible_event_statuses)
    calculate :upcoming?, :boolean, expr(starts_at > now())
    calculate :past?, :boolean, expr(starts_at <= now())

    # RSVPs are open until end_time (or 2 hours after start if no end_time)
    calculate :rsvps_open?, :boolean, expr(
      if is_nil(ends_at) do
        datetime_add(starts_at, 2, :hour) > now()
      else
        ends_at > now()
      end
    )
  end
end
