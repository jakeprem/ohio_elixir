defmodule OhioElixir.Accounts.User do
  use Ash.Resource,
    otp_app: :ohio_elixir,
    domain: OhioElixir.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshJsonApi.Resource]

  sqlite do
    table "users"
    repo OhioElixir.Repo
  end

  json_api do
    type "user"

    routes do
      base "/users"

      get :me, route: "/me"
    end
  end

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource OhioElixir.Accounts.Token
      signing_secret OhioElixir.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true

        sender OhioElixir.Accounts.User.Senders.SendMagicLinkEmail
      end
    end
  end

  actions do
    defaults [:read]

    read :me do
      description "Get the current authenticated user"
      get? true
      filter expr(id == ^actor(:id))
    end

    create :seed do
      description "Create a user for seeding purposes (no authentication)"
      accept [:email, :role]
    end

    create :find_or_create_by_email do
      description "Find or create user by email for guest RSVP"
      argument :email, :ci_string, allow_nil?: false
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]
      change set_attribute(:email, arg(:email))
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      argument :email, :ci_string, allow_nil?: false
      get? true
      filter expr(email == ^arg(:email))
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      description "Request a magic link to be sent to the user's email."

      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action(:find_or_create_by_email) do
      authorize_if always()
    end

    policy action(:me) do
      authorize_if actor_present()
    end

    # Allow admins to read users (for attendee lists, etc.)
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      allow_nil? false
      default :user
      public? true
      constraints one_of: [:user, :admin]
    end
  end

  relationships do
    has_many :created_events, OhioElixir.Events.Event do
      destination_attribute :created_by_id
    end

    has_many :rsvps, OhioElixir.Events.Rsvp
  end

  identities do
    identity :unique_email, [:email]
  end
end
