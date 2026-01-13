defmodule OhioElixirWeb.EventFormLive do
  @moduledoc """
  LiveView for creating and editing events.
  Admin-only access.
  """
  use OhioElixirWeb, :live_view

  alias OhioElixir.Events
  alias OhioElixir.Events.Event
  alias OhioElixir.Events.Venue

  on_mount {OhioElixirWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    venues = Events.list_venues!(actor: current_user)
    venue_options = Enum.map(venues, &{&1.name, &1.id})

    socket =
      assign(socket,
        venues: venues,
        venue_options: venue_options,
        page_title: "New Event",
        show_venue_form: false,
        venue_form: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    current_user = socket.assigns.current_user

    if Ash.can?({Event, :create}, current_user) do
      form =
        Event
        |> AshPhoenix.Form.for_create(:create,
          as: "event",
          actor: current_user
        )
        |> to_form()

      socket
      |> assign(page_title: "New Event")
      |> assign(event: nil)
      |> assign(form: form)
    else
      socket
      |> put_flash(:error, "You don't have permission to create events")
      |> push_navigate(to: ~p"/events")
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    current_user = socket.assigns.current_user

    case Events.get_event(id, actor: current_user) do
      {:ok, event} ->
        if Ash.can?({event, :update}, current_user) do
          form =
            event
            |> AshPhoenix.Form.for_update(:update,
              as: "event",
              actor: current_user
            )
            |> to_form()

          socket
          |> assign(page_title: "Edit Event")
          |> assign(event: event)
          |> assign(form: form)
        else
          socket
          |> put_flash(:error, "You don't have permission to edit this event")
          |> push_navigate(to: ~p"/events/#{id}")
        end

      {:error, _} ->
        socket
        |> put_flash(:error, "Event not found")
        |> push_navigate(to: ~p"/events")
    end
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"event" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, event_saved_message(socket.assigns.live_action))
         |> push_navigate(to: ~p"/events/#{event.id}")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("toggle_venue_form", _params, socket) do
    if socket.assigns.show_venue_form do
      {:noreply, assign(socket, show_venue_form: false, venue_form: nil)}
    else
      venue_form =
        Venue
        |> AshPhoenix.Form.for_create(:create,
          as: "venue",
          actor: socket.assigns.current_user
        )
        |> to_form()

      {:noreply, assign(socket, show_venue_form: true, venue_form: venue_form)}
    end
  end

  @impl true
  def handle_event("validate_venue", %{"venue" => params}, socket) do
    venue_form =
      socket.assigns.venue_form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, venue_form: venue_form)}
  end

  @impl true
  def handle_event("save_venue", %{"venue" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.venue_form.source, params: params) do
      {:ok, venue} ->
        venues = Events.list_venues!(actor: socket.assigns.current_user)
        venue_options = Enum.map(venues, &{&1.name, &1.id})

        # Update the event form to select the new venue
        event_form =
          socket.assigns.form.source
          |> AshPhoenix.Form.validate(%{"venue_id" => venue.id})
          |> to_form()

        {:noreply,
         socket
         |> assign(
           venues: venues,
           venue_options: venue_options,
           show_venue_form: false,
           venue_form: nil,
           form: event_form
         )
         |> put_flash(:info, "Venue created")}

      {:error, form} ->
        {:noreply, assign(socket, venue_form: to_form(form))}
    end
  end

  defp event_saved_message(:new), do: "Event created successfully"
  defp event_saved_message(:edit), do: "Event updated successfully"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <header class="border-b border-base-300 py-8">
        <div class="max-w-3xl mx-auto px-6">
          <div class="mb-4">
            <.link
              navigate={~p"/events"}
              class="text-base-content/60 hover:text-base-content flex items-center gap-1 text-sm"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" />
              Back to events
            </.link>
          </div>
          <h1 class="text-3xl font-bold">{@page_title}</h1>
        </div>
      </header>

      <div class="max-w-3xl mx-auto px-6 py-8">
        <.form for={@form} id="event-form" phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="border border-base-300 p-6 space-y-4">
            <h2 class="text-lg font-bold">Basic Information</h2>

            <.input
              field={@form[:format]}
              type="select"
              label="Format"
              options={[
                {"In Person", :in_person},
                {"Online", :online},
                {"Hybrid", :hybrid}
              ]}
            />

            <.input field={@form[:title]} label="Title" required />

            <.input
              field={@form[:short_description]}
              type="textarea"
              label="Short Description"
              rows="2"
              placeholder="Brief summary for event cards (max 300 chars)"
            />

            <.input field={@form[:description]} type="textarea" label="Description" rows="5" />
          </div>

          <div class="border border-base-300 p-6 space-y-4">
            <h2 class="text-lg font-bold">Date & Time</h2>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:starts_at]} type="datetime-local" label="Start Time" required />
              <.input field={@form[:ends_at]} type="datetime-local" label="End Time" />
            </div>

            <.input field={@form[:timezone]} type="select" label="Timezone" options={timezone_options()} />
          </div>

          <div class="border border-base-300 p-6 space-y-4">
            <h2 class="text-lg font-bold">Location</h2>

            <div>
              <div class="flex items-start gap-2">
                <div class="flex-1">
                  <.input
                    field={@form[:venue_id]}
                    type="select"
                    label="Venue (for in-person/hybrid)"
                    options={@venue_options}
                    prompt="Select a venue..."
                  />
                </div>
                <button
                  type="button"
                  phx-click="toggle_venue_form"
                  class="btn btn-sm btn-ghost text-primary mt-7"
                >
                  <%= if @show_venue_form, do: "Cancel", else: "+ New" %>
                </button>
              </div>

              <%= if @show_venue_form do %>
                <div class="border border-base-300 p-4 mt-2 space-y-3 bg-base-200/50">
                  <h3 class="text-sm font-medium">New Venue</h3>
                  <.input field={@venue_form[:name]} label="Name" phx-change="validate_venue" required />
                  <.input field={@venue_form[:address_line_1]} label="Address" phx-change="validate_venue" />
                  <div class="grid grid-cols-3 gap-2">
                    <.input field={@venue_form[:city]} label="City" phx-change="validate_venue" />
                    <.input field={@venue_form[:state]} label="State" phx-change="validate_venue" />
                    <.input field={@venue_form[:postal_code]} label="Postal Code" phx-change="validate_venue" />
                  </div>
                  <button
                    type="button"
                    phx-click="save_venue"
                    phx-value-venue={Jason.encode!(@venue_form.params || %{})}
                    class="btn btn-sm btn-primary"
                  >
                    Save Venue
                  </button>
                </div>
              <% end %>
            </div>

            <.input
              field={@form[:meeting_url]}
              type="url"
              label="Meeting URL (for online/hybrid)"
              placeholder="https://zoom.us/..."
            />

            <.input field={@form[:capacity]} type="number" label="Capacity (optional)" min="1" />
          </div>

          <div class="flex gap-4 justify-end">
            <.link navigate={if @live_action == :edit, do: ~p"/events/#{@event.id}", else: ~p"/events"} class="btn btn-ghost">
              Cancel
            </.link>
            <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
              <%= if @live_action == :new, do: "Create Event", else: "Save Changes" %>
            </button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp timezone_options do
    [
      {"Eastern Time (America/New_York)", "America/New_York"},
      {"Central Time (America/Chicago)", "America/Chicago"},
      {"Mountain Time (America/Denver)", "America/Denver"},
      {"Pacific Time (America/Los_Angeles)", "America/Los_Angeles"},
      {"UTC", "Etc/UTC"}
    ]
  end
end
