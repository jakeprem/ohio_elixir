defmodule OhioElixir.Events.Venue do
  use Ash.Resource,
    otp_app: :ohio_elixir,
    domain: OhioElixir.Events,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource, AshJsonApi.Resource]

  sqlite do
    table "venues"
    repo OhioElixir.Repo
  end

  json_api do
    type "venue"

    routes do
      base "/venues"

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :address_line_1, :string do
      public? true
    end

    attribute :address_line_2, :string do
      public? true
    end

    attribute :city, :string do
      public? true
    end

    attribute :state, :string do
      public? true
    end

    attribute :postal_code, :string do
      public? true
    end

    attribute :country, :string do
      default "US"
      public? true
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :website_url, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :events, OhioElixir.Events.Event
  end
end
