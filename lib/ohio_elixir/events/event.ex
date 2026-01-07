defmodule OhioElixir.Events.Event do
  use Ash.Resource,
    otp_app: :ohio_elixir,
    domain: OhioElixir.Events,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource, AshJsonApi.Resource]

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
    defaults [:read, :destroy]

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
      authorize_if expr(status == :published)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
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
      attribute_writable? true
    end

    has_many :rsvps, OhioElixir.Events.Rsvp
  end

  calculations do
    calculate :rsvp_count, :integer,
              expr(
                fragment(
                  "(SELECT COUNT(*) FROM event_rsvps WHERE event_id = ? AND status = 'confirmed')",
                  id
                )
              )

    calculate :upcoming?, :boolean, expr(starts_at > now())
    calculate :past?, :boolean, expr(starts_at <= now())
  end
end
