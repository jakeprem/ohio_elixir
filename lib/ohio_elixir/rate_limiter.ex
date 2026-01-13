defmodule OhioElixir.RateLimiter do
  @moduledoc """
  Rate limiter using Hammer with ETS backend.

  This module provides the rate limiting backend for the application.
  It is started in the application supervision tree and uses ETS for storage.
  """

  use Hammer, backend: :ets
end
