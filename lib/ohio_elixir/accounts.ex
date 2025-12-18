defmodule OhioElixir.Accounts do
  use Ash.Domain, otp_app: :ohio_elixir, extensions: [AshAdmin.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  json_api do
    log_errors? true
  end

  resources do
    resource OhioElixir.Accounts.Token

    resource OhioElixir.Accounts.User do
      define :find_or_create_user_by_email, action: :find_or_create_by_email, args: [:email]
      define :get_user_by_email, action: :get_by_email, args: [:email]
    end
  end
end
