defmodule OhioElixir.Errors.JsonApiErrors do
  @moduledoc """
  Custom AshJsonApi error implementations for proper HTTP status codes.
  """

  defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Query.ReadActionRequiresActor do
    def to_json_api_error(_error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 401,
        code: "unauthorized",
        title: "Unauthorized",
        detail: "Authentication required"
      }
    end
  end
end
