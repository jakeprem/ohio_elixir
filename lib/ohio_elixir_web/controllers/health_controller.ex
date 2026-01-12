defmodule OhioElixirWeb.HealthController do
  use OhioElixirWeb, :controller

  def index(conn, _params) do
    case Ecto.Adapters.SQL.query(OhioElixir.Repo, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{status: "healthy"})

      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unhealthy"})
    end
  end
end
