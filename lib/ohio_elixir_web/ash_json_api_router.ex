defmodule OhioElixirWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [OhioElixir.Events, OhioElixir.Accounts],
    open_api: "/open_api"
end
