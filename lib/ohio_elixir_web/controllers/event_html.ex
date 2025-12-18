defmodule OhioElixirWeb.EventHTML do
  @moduledoc """
  This module contains pages rendered by EventController.

  See the `event_html` directory for all templates available.
  """
  use OhioElixirWeb, :html

  embed_templates "event_html/*"

  # Delegate formatting helpers to PageHTML to avoid duplication
  defdelegate format_date(datetime, timezone), to: OhioElixirWeb.PageHTML
  defdelegate format_time(datetime, timezone), to: OhioElixirWeb.PageHTML
  defdelegate format_badge(assigns), to: OhioElixirWeb.PageHTML
end
