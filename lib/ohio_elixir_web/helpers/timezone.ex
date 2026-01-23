defmodule OhioElixirWeb.Helpers.Timezone do
  @moduledoc """
  Helper functions for converting between UTC datetimes and local timezone representations.

  Used primarily for form inputs (datetime-local) which require naive datetime strings,
  while we store all datetimes as UTC in the database.
  """

  @default_display_timezone "America/New_York"

  @doc """
  Converts a naive datetime string from form input to UTC DateTime,
  interpreting the input as being in the given timezone.

  ## Examples

      iex> naive_to_utc("2026-01-27T12:30", "America/New_York")
      ~U[2026-01-27 17:30:00Z]

      iex> naive_to_utc(nil, "America/New_York")
      nil

      iex> naive_to_utc("", "America/New_York")
      nil
  """
  def naive_to_utc(nil, _timezone), do: nil
  def naive_to_utc("", _timezone), do: nil

  # Already a DateTime - return as-is (happens when transform_params is called multiple times)
  def naive_to_utc(%DateTime{} = datetime, _timezone), do: datetime

  def naive_to_utc(naive_string, timezone) when is_binary(naive_string) do
    # datetime-local inputs come without seconds, so we append ":00"
    with {:ok, naive} <- NaiveDateTime.from_iso8601(naive_string <> ":00"),
         {:ok, local_dt} <- DateTime.from_naive(naive, timezone),
         {:ok, utc_dt} <- DateTime.shift_zone(local_dt, "Etc/UTC") do
      utc_dt
    else
      _ -> nil
    end
  end

  @doc """
  Converts a UTC DateTime to a naive datetime string for form input,
  displayed in the given timezone.

  Returns a string in the format "YYYY-MM-DDTHH:MM" suitable for
  datetime-local inputs.

  ## Examples

      iex> utc_to_naive(~U[2026-01-27 17:30:00Z], "America/New_York")
      "2026-01-27T12:30"

      iex> utc_to_naive(nil, "America/New_York")
      nil
  """
  def utc_to_naive(nil, _timezone), do: nil

  def utc_to_naive(utc_datetime, timezone) do
    case DateTime.shift_zone(utc_datetime, timezone) do
      {:ok, local_dt} -> Calendar.strftime(local_dt, "%Y-%m-%dT%H:%M")
      {:error, _} -> Calendar.strftime(utc_datetime, "%Y-%m-%dT%H:%M")
    end
  end

  @doc """
  Returns the display timezone for a user, defaulting to America/New_York.

  In the future, this could read from user preferences.
  """
  def display_timezone(_user), do: @default_display_timezone

  @doc """
  Returns the default timezone used for this application.
  """
  def default_timezone, do: @default_display_timezone
end
