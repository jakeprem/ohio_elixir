defmodule OhioElixir.CliAuth do
  @moduledoc """
  Manages CLI authentication flow.

  Flow:
  1. CLI generates random code, opens browser to /cli/auth?code=<code>
  2. User logs in via magic link
  3. After login, token is stored with the code
  4. CLI polls /api/cli/auth/poll?code=<code> to retrieve token
  5. Token is removed after retrieval or expiration
  """

  use GenServer

  @table :cli_auth_pending
  @expiration_ms :timer.minutes(10)
  @cleanup_interval_ms :timer.minutes(1)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Registers a pending CLI auth request. Returns :ok if the code is valid.
  """
  def register_pending(code) when is_binary(code) and byte_size(code) >= 16 do
    ensure_table_exists()
    expires_at = System.monotonic_time(:millisecond) + @expiration_ms
    :ets.insert(@table, {code, :pending, expires_at})
    :ok
  end

  def register_pending(_code), do: {:error, :invalid_code}

  defp ensure_table_exists do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])

      _ref ->
        :ok
    end
  rescue
    ArgumentError ->
      # Table exists but was created by another process, that's fine
      :ok
  end

  @doc """
  Checks if a code is pending (waiting for auth).
  """
  def pending?(code) do
    case :ets.lookup(@table, code) do
      [{^code, :pending, expires_at}] ->
        System.monotonic_time(:millisecond) < expires_at

      _ ->
        false
    end
  end

  @doc """
  Completes the auth flow by storing the token for a code.
  """
  def complete(code, token, user_email) when is_binary(token) do
    case :ets.lookup(@table, code) do
      [{^code, :pending, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          :ets.insert(@table, {code, {:complete, token, user_email}, expires_at})
          :ok
        else
          :ets.delete(@table, code)
          {:error, :expired}
        end

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Retrieves and removes a completed token. Returns {:ok, token, email} or {:error, reason}.
  """
  def retrieve(code) do
    case :ets.lookup(@table, code) do
      [{^code, {:complete, token, email}, _expires_at}] ->
        :ets.delete(@table, code)
        {:ok, token, email}

      [{^code, :pending, _expires_at}] ->
        {:error, :pending}

      _ ->
        {:error, :not_found}
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create ETS table, handling case where it might already exist (hot reload)
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])

      _ref ->
        # Table already exists, nothing to do
        :ok
    end

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)

    # Delete all expired entries
    :ets.select_delete(@table, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
