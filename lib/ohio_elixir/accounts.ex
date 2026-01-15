defmodule OhioElixir.Accounts do
  use Ash.Domain, otp_app: :ohio_elixir, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource OhioElixir.Accounts.Token
    resource OhioElixir.Accounts.User
  end
end
