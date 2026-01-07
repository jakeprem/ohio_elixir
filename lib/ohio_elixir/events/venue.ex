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

    attribute :address_line_1, :string, public?: true
    attribute :address_line_2, :string, public?: true
    attribute :city, :string, public?: true
    attribute :state, :string, public?: true
    attribute :postal_code, :string, public?: true
    attribute :country, :string, public?: true, default: "US"
    attribute :notes, :string, public?: true, constraints: [max_length: 2000]
    attribute :website_url, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :events, OhioElixir.Events.Event
  end
end
