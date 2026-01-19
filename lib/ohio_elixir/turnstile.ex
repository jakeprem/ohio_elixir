defmodule OhioElixir.Turnstile do
  @moduledoc """
  Cloudflare Turnstile verification for bot protection.

  Turnstile is a privacy-preserving CAPTCHA alternative that validates
  users without requiring interaction in most cases.

  ## Configuration

  Add to your config:

      config :ohio_elixir, :turnstile,
        site_key: System.get_env("TURNSTILE_SITE_KEY"),
        secret_key: System.get_env("TURNSTILE_SECRET_KEY")

  ## Usage

  In your LiveView template:

      <div
        id="turnstile-widget"
        phx-hook="Turnstile"
        data-sitekey={OhioElixir.Turnstile.site_key()}
      ></div>

  Then verify the token server-side:

      case OhioElixir.Turnstile.verify(token) do
        :ok -> # proceed
        {:error, _} -> # reject
      end
  """

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  @doc """
  Verifies a Turnstile token with Cloudflare.

  Returns `:ok` on success, `{:error, reason}` on failure.

  ## Options

  - `remote_ip` - The user's IP address (optional, improves accuracy)

  ## Examples

      iex> OhioElixir.Turnstile.verify("valid-token")
      :ok

      iex> OhioElixir.Turnstile.verify("invalid-token")
      {:error, ["invalid-input-response"]}
  """
  def verify(token, remote_ip \\ nil)

  def verify(nil, _remote_ip), do: {:error, :missing_token}
  def verify("", _remote_ip), do: {:error, :missing_token}

  def verify(token, remote_ip) do
    body =
      %{
        secret: secret_key(),
        response: token
      }
      |> maybe_add_ip(remote_ip)

    case Req.post(@verify_url, json: body) do
      {:ok, %{body: %{"success" => true}}} ->
        :ok

      {:ok, %{body: %{"success" => false, "error-codes" => codes}}} ->
        {:error, codes}

      {:ok, %{body: body}} ->
        {:error, {:unexpected_response, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp maybe_add_ip(body, nil), do: body
  defp maybe_add_ip(body, ip), do: Map.put(body, :remoteip, ip)

  @doc """
  Returns the public site key for client-side widget rendering.
  """
  def site_key do
    Application.get_env(:ohio_elixir, :turnstile)[:site_key]
  end

  @doc """
  Returns whether Turnstile is configured and enabled.
  """
  def enabled? do
    site_key() != nil && secret_key() != nil
  end

  defp secret_key do
    Application.get_env(:ohio_elixir, :turnstile)[:secret_key]
  end
end
