defmodule OhioElixir.Accounts.UserPreferences do
  @moduledoc """
  Embedded resource for user preferences.

  Stored as JSON in the user's `preferences` column.
  """
  use Ash.Resource,
    otp_app: :ohio_elixir,
    data_layer: :embedded

  attributes do
    attribute :use_gravatar, :boolean do
      description "Whether to show Gravatar avatar or initials"
      allow_nil? false
      default true
      public? true
    end
  end
end
