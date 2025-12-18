defmodule OhioElixir.Events.Calculations.RsvpCount do
  @moduledoc """
  Calculates the count of confirmed RSVPs for an event.

  Since SQLite doesn't support aggregates, we load the RSVPs relationship
  and count them in Elixir.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    # Need to load rsvps with the status attribute
    [rsvps: [:status]]
  end

  @impl true
  def calculate(records, _opts, _context) do
    results =
      Enum.map(records, fn record ->
        case record.rsvps do
          %Ash.NotLoaded{} ->
            0

          list when is_list(list) ->
            Enum.count(list, &(&1.status == :confirmed))

          _ ->
            0
        end
      end)

    {:ok, results}
  end
end
