defmodule OhioElixirWeb.EventHTML do
  @moduledoc """
  This module contains pages rendered by EventController.

  See the `event_html` directory for all templates available.
  """
  use OhioElixirWeb, :html

  embed_templates "event_html/*"

  @doc """
  Check if meeting URL should be shown based on RSVP status and user role.

  Returns true if:
  - User is an admin
  - User has a confirmed RSVP for the event
  """
  def show_meeting_url?(existing_rsvp, current_user) do
    cond do
      current_user && current_user.role == :admin -> true
      existing_rsvp && existing_rsvp.status == :confirmed -> true
      true -> false
    end
  end
end
