defmodule OhioElixir.Events.Changes.FindOrCreateUserByEmail do
  @moduledoc """
  Custom Ash change that finds or creates a user by email,
  then sets the user relationship on the RSVP.

  Used for guest RSVP flow where we don't have an authenticated actor.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      email = Ash.Changeset.get_argument(changeset, :email)

      case OhioElixir.Accounts.User
           |> Ash.Changeset.for_create(:find_or_create_by_email, %{email: email})
           |> Ash.create() do
        {:ok, user} ->
          Ash.Changeset.manage_relationship(changeset, :user, user, type: :append)

        {:error, error} ->
          Ash.Changeset.add_error(changeset, error)
      end
    end)
  end
end
