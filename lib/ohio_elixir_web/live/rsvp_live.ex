defmodule OhioElixirWeb.RsvpLive do
  @moduledoc """
  Embedded LiveView for RSVP functionality on event pages.

  Handles both authenticated users (one-click RSVP) and guests (email form).
  """
  use OhioElixirWeb, :live_view

  alias OhioElixir.Events
  alias OhioElixir.Events.Rsvp

  on_mount {OhioElixirWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, session, socket) do
    event_id = session["event_id"]
    event_format = session["event_format"]
    venue_name = session["venue_name"]
    meeting_url = session["meeting_url"]
    existing_rsvp_id = session["existing_rsvp_id"]

    if connected?(socket) do
      current_user = socket.assigns[:current_user]

      # Load existing RSVP if we have one
      existing_rsvp =
        cond do
          existing_rsvp_id ->
            case Ash.get(Rsvp, existing_rsvp_id) do
              {:ok, rsvp} -> rsvp
              _ -> nil
            end

          current_user ->
            case Events.get_rsvp_by_email_and_event(current_user.email, event_id) do
              {:ok, rsvp} -> rsvp
              _ -> nil
            end

          true ->
            nil
        end

      rsvp_status = determine_rsvp_status(existing_rsvp)

      socket =
        socket
        |> assign(
          loading: false,
          event_id: event_id,
          event_format: event_format,
          venue_name: venue_name,
          meeting_url: meeting_url,
          existing_rsvp: existing_rsvp,
          rsvp_status: rsvp_status,
          form: nil,
          submitting: false,
          selected_mode: default_attendance_mode(event_format)
        )
        |> maybe_build_form(rsvp_status)

      {:ok, socket}
    else
      # Not connected yet - show loading state
      {:ok,
       assign(socket,
         loading: true,
         event_id: event_id,
         event_format: event_format,
         venue_name: venue_name,
         meeting_url: meeting_url,
         existing_rsvp: nil,
         rsvp_status: :loading,
         form: nil,
         submitting: false,
         selected_mode: default_attendance_mode(event_format)
       )}
    end
  end

  defp default_attendance_mode(:in_person), do: :in_person
  defp default_attendance_mode(:online), do: :online
  defp default_attendance_mode(:hybrid), do: :in_person
  defp default_attendance_mode(_), do: nil

  defp determine_rsvp_status(nil), do: :not_rsvped
  defp determine_rsvp_status(%{status: :confirmed}), do: :already_rsvped
  defp determine_rsvp_status(%{status: :cancelled}), do: :cancelled
  defp determine_rsvp_status(%{status: :waitlisted}), do: :waitlisted
  defp determine_rsvp_status(_), do: :not_rsvped

  defp maybe_build_form(socket, :not_rsvped) do
    if is_nil(socket.assigns[:current_user]) do
      form =
        Rsvp
        |> AshPhoenix.Form.for_create(:guest_rsvp,
          as: "rsvp",
          params: %{"event_id" => socket.assigns.event_id}
        )
        |> to_form()

      assign(socket, form: form)
    else
      socket
    end
  end

  defp maybe_build_form(socket, _status), do: socket

  @impl true
  def handle_event("rsvp", _params, socket) do
    current_user = socket.assigns[:current_user]
    event_id = socket.assigns.event_id
    attendance_mode = socket.assigns.selected_mode

    socket = assign(socket, submitting: true)

    opts = [actor: current_user]

    opts =
      if attendance_mode do
        Keyword.put(opts, :params, %{attendance_mode: attendance_mode})
      else
        opts
      end

    case Events.rsvp_to_event(event_id, opts) do
      {:ok, rsvp} ->
        {:noreply,
         assign(socket,
           existing_rsvp: rsvp,
           rsvp_status: :already_rsvped,
           submitting: false
         )}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(error))
         |> assign(submitting: false)}
    end
  end

  @impl true
  def handle_event("select_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, selected_mode: String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("validate", %{"rsvp" => params}, socket) do
    # Ensure event_id is always included in validation
    params = Map.put(params, "event_id", socket.assigns.event_id)

    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"rsvp" => params}, socket) do
    socket = assign(socket, submitting: true)

    params =
      params
      |> Map.put("event_id", socket.assigns.event_id)
      |> Map.put("attendance_mode", socket.assigns.selected_mode)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, rsvp} ->
        {:noreply,
         assign(socket,
           existing_rsvp: rsvp,
           rsvp_status: :already_rsvped,
           submitting: false
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form), submitting: false)}
    end
  end

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(&format_single_error/1)
    |> Enum.join(", ")
  end

  defp format_error(error), do: "Could not complete RSVP: #{inspect(error)}"

  defp format_single_error(%Ash.Error.Changes.InvalidChanges{message: message}), do: message
  defp format_single_error(%{message: message}), do: message
  defp format_single_error(error), do: inspect(error)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rsvp-component">
      <%= case @rsvp_status do %>
        <% :loading -> %>
          <div class="flex justify-center py-4">
            <span class="loading loading-spinner loading-md"></span>
          </div>
        <% :already_rsvped -> %>
          <div class="flex flex-col items-center gap-2 py-2">
            <span class="badge badge-success gap-2">
              <.icon name="hero-check-circle" class="w-4 h-4" />
              You're going!
            </span>
            <.attendance_mode_info
              mode={@existing_rsvp.attendance_mode || @selected_mode}
              venue_name={@venue_name}
              meeting_url={@meeting_url}
            />
          </div>
        <% :waitlisted -> %>
          <div class="flex flex-col items-center gap-2 py-2">
            <span class="badge badge-warning gap-2">
              <.icon name="hero-clock" class="w-4 h-4" />
              Waitlisted
            </span>
            <p class="text-sm text-base-content/60">We'll notify you if a spot opens up</p>
          </div>
        <% :cancelled -> %>
          <div class="flex flex-col items-center gap-2 py-2">
            <span class="text-base-content/70">RSVP cancelled</span>
          </div>
        <% :not_rsvped -> %>
          <div class="space-y-3">
            <.attendance_mode_selector
              :if={@event_format == :hybrid}
              selected_mode={@selected_mode}
            />

            <.attendance_mode_info
              mode={@selected_mode}
              venue_name={@venue_name}
              meeting_url={@meeting_url}
            />

            <%= if @current_user do %>
              <%!-- Authenticated user: simple button --%>
              <button
                phx-click="rsvp"
                class="btn btn-primary w-full"
                disabled={@submitting}
              >
                <%= if @submitting do %>
                  <span class="loading loading-spinner loading-sm"></span>
                <% else %>
                  <.icon name="hero-hand-raised" class="w-5 h-5" />
                <% end %>
                RSVP
              </button>
            <% else %>
              <%!-- Guest: show email form --%>
              <.form for={@form} phx-change="validate" phx-submit="submit" class="space-y-3">
                <div>
                  <.input
                    field={@form[:email]}
                    type="email"
                    placeholder="Enter your email"
                    required
                    class="input input-bordered w-full"
                  />
                </div>
                <button
                  type="submit"
                  class="btn btn-primary w-full"
                  disabled={@submitting || !@form.source.valid?}
                >
                  <%= if @submitting do %>
                    <span class="loading loading-spinner loading-sm"></span>
                  <% else %>
                    <.icon name="hero-hand-raised" class="w-5 h-5" />
                  <% end %>
                  RSVP
                </button>
                <p class="text-xs text-base-content/60 text-center">
                  We'll send event updates to this email
                </p>
              </.form>
            <% end %>
          </div>
      <% end %>
    </div>
    """
  end

  defp attendance_mode_selector(assigns) do
    ~H"""
    <div class="flex gap-2">
      <button
        type="button"
        phx-click="select_mode"
        phx-value-mode="in_person"
        class={[
          "btn btn-sm flex-1",
          if(@selected_mode == :in_person, do: "btn-primary", else: "btn-outline")
        ]}
      >
        <.icon name="hero-map-pin" class="w-4 h-4" />
        In Person
      </button>
      <button
        type="button"
        phx-click="select_mode"
        phx-value-mode="online"
        class={[
          "btn btn-sm flex-1",
          if(@selected_mode == :online, do: "btn-primary", else: "btn-outline")
        ]}
      >
        <.icon name="hero-video-camera" class="w-4 h-4" />
        Online
      </button>
    </div>
    """
  end

  defp attendance_mode_info(assigns) do
    ~H"""
    <div class="text-sm text-base-content/60 text-center">
      <%= case @mode do %>
        <% :in_person -> %>
          <div class="flex items-center justify-center gap-1">
            <.icon name="hero-map-pin" class="w-4 h-4" />
            <%= if @venue_name do %>
              <span>{@venue_name}</span>
            <% else %>
              <span>In person</span>
            <% end %>
          </div>
        <% :online -> %>
          <div class="flex items-center justify-center gap-1">
            <.icon name="hero-video-camera" class="w-4 h-4" />
            <span>Online</span>
          </div>
        <% _ -> %>
          <span>We'll see you there</span>
      <% end %>
    </div>
    """
  end
end
