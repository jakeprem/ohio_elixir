defmodule OhioElixirWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use OhioElixirWeb, :html

  embed_templates "page_html/*"

  @doc """
  Formats a datetime for display as a date string.
  Falls back to UTC if timezone database doesn't support the timezone.
  """
  def format_date(datetime, timezone) do
    datetime
    |> shift_zone_or_utc(timezone)
    |> Calendar.strftime("%B %d, %Y")
  end

  @doc """
  Formats a datetime for display as a time string.
  Falls back to UTC if timezone database doesn't support the timezone.
  """
  def format_time(datetime, timezone) do
    datetime
    |> shift_zone_or_utc(timezone)
    |> Calendar.strftime("%I:%M %p")
  end

  defp shift_zone_or_utc(datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, shifted} -> shifted
      {:error, _} -> datetime
    end
  end

  @doc """
  Renders a badge showing the event format (in_person, online, hybrid).
  """
  attr :format, :atom, required: true

  def format_badge(assigns) do
    {label, class} =
      case assigns.format do
        :in_person -> {"In Person", "badge-primary"}
        :online -> {"Online", "badge-secondary"}
        :hybrid -> {"Hybrid", "badge-accent"}
      end

    assigns = assign(assigns, label: label, class: class)

    ~H"""
    <span class={["badge badge-sm", @class]}>{@label}</span>
    """
  end
end
