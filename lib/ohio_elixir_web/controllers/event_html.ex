defmodule OhioElixirWeb.EventHTML do
  @moduledoc """
  This module contains pages rendered by EventController.

  See the `event_html` directory for all templates available.
  """
  use OhioElixirWeb, :html

  embed_templates "event_html/*"

  attr :label, :string, required: true
  attr :rsvps, :list, default: nil

  defp attendee_group(%{rsvps: nil} = assigns), do: ~H""
  defp attendee_group(%{rsvps: []} = assigns), do: ~H""

  defp attendee_group(assigns) do
    ~H"""
    <div>
      <h3 class="text-sm font-semibold text-base-content/70 border-b border-base-300 pb-1 mb-2">
        {@label} ({length(@rsvps)})
      </h3>
      <ul class="space-y-1">
        <li :for={rsvp <- @rsvps} class="text-sm">{format_attendee_name(rsvp.user)}</li>
      </ul>
    </div>
    """
  end

  @doc """
  Renders an event card for the events list.

  Expects the event to have the `:upcoming?` calculation loaded.
  """
  attr :event, :map, required: true

  def event_card(assigns) do
    assigns = assign(assigns, :upcoming?, assigns.event.upcoming?)

    ~H"""
    <div class="border border-base-300 hover:border-primary/50 transition-colors">
      <div class="p-4 text-left">
        <.link href={~p"/events/#{@event.id}"} data-instant class="block mb-4">
          <div class="flex flex-wrap items-center gap-2 mb-2">
            <span class="text-sm text-base-content/50">
              {format_date(@event.starts_at, @event.timezone)} · {format_time(
                @event.starts_at,
                @event.timezone
              )}
            </span>
            <.format_badge format={@event.format} />
            <%= if @event.status == :draft do %>
              <span class="badge badge-warning badge-sm">Draft</span>
            <% end %>
            <%= if @event.status == :cancelled do %>
              <span class="badge badge-error badge-sm">Cancelled</span>
            <% end %>
          </div>
          <h4 class="text-lg font-bold mb-2">{@event.title}</h4>
          <%= if @event.short_description do %>
            <p class="text-base-content/60 text-sm line-clamp-2">{@event.short_description}</p>
          <% else %>
            <%= if @event.description do %>
              <p class="text-base-content/60 text-sm line-clamp-2">
                {String.slice(@event.description, 0, 200)}{if String.length(@event.description || "") >
                                                                200,
                                                              do: "..."}
              </p>
            <% end %>
          <% end %>
        </.link>
        <%= if @upcoming? do %>
          <div class="flex flex-col sm:flex-row gap-2">
            <%= if @event.format in [:in_person, :hybrid] do %>
              <.link
                navigate={~p"/events/#{@event.id}?mode=in_person"}
                class="btn btn-primary btn-sm"
              >
                Join In Person
              </.link>
            <% end %>
            <%= if @event.format in [:online, :hybrid] do %>
              <.link
                navigate={~p"/events/#{@event.id}?mode=online"}
                class="btn btn-outline btn-primary btn-sm"
              >
                Join Online
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
