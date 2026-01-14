defmodule OhioElixirWeb.CliAuthController do
  @moduledoc """
  Controller for CLI authentication API endpoints.
  """
  use OhioElixirWeb, :controller

  alias OhioElixir.CliAuth

  @doc """
  Stores the CLI auth code in session and redirects to sign-in.
  This is called when CLI opens browser to /cli/auth?code=<code>.
  If user is already logged in, skips to callback directly.
  """
  def start(conn, %{"code" => code}) when byte_size(code) >= 16 do
    case CliAuth.register_pending(code) do
      :ok ->
        conn = put_session(conn, :cli_auth_code, code)

        # If user is already logged in, skip sign-in and go to callback
        if conn.assigns[:current_user] do
          redirect(conn, to: ~p"/cli/auth/callback")
        else
          conn
          |> put_session(:return_to, ~p"/cli/auth/callback")
          |> redirect(to: ~p"/sign-in")
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid CLI authentication code")
        |> redirect(to: ~p"/")
    end
  end

  def start(conn, _params) do
    conn
    |> put_flash(:error, "Invalid or missing CLI authentication code. Please run `ohio login` from your terminal.")
    |> redirect(to: ~p"/")
  end

  @doc """
  Callback after successful magic link login.
  Generates a token and completes the CLI auth flow.
  """
  def callback(conn, _params) do
    code = get_session(conn, :cli_auth_code)
    user = conn.assigns[:current_user]

    cond do
      is_nil(code) ->
        conn
        |> put_flash(:error, "No CLI authentication in progress")
        |> redirect(to: ~p"/")

      is_nil(user) ->
        conn
        |> put_flash(:error, "You must be signed in to complete CLI authentication")
        |> redirect(to: ~p"/sign-in")

      true ->
        case AshAuthentication.Jwt.token_for_user(user) do
          {:ok, token, _claims} ->
            case CliAuth.complete(code, token, to_string(user.email)) do
              :ok ->
                conn
                |> delete_session(:cli_auth_code)
                |> render(:callback_success, user: user)

              {:error, :expired} ->
                conn
                |> delete_session(:cli_auth_code)
                |> put_flash(:error, "CLI authentication session expired. Please run `ohio login` again.")
                |> redirect(to: ~p"/")

              {:error, _} ->
                conn
                |> delete_session(:cli_auth_code)
                |> put_flash(:error, "Failed to complete CLI authentication")
                |> redirect(to: ~p"/")
            end

          {:error, _} ->
            conn
            |> put_flash(:error, "Failed to generate authentication token")
            |> redirect(to: ~p"/")
        end
    end
  end

  @doc """
  API endpoint for CLI to poll for completed authentication.
  Returns JSON with the token or status.
  """
  def poll(conn, %{"code" => code}) do
    case CliAuth.retrieve(code) do
      {:ok, token, email} ->
        json(conn, %{status: "complete", token: token, email: email})

      {:error, :pending} ->
        json(conn, %{status: "pending"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "not_found", error: "Authentication code not found or expired"})
    end
  end

  def poll(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{status: "error", error: "Missing code parameter"})
  end
end
