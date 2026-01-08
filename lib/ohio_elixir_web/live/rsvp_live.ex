defmodule OhioElixirWeb.RsvpLive do
  @moduledoc """
  Embedded LiveView for RSVP functionality on event pages.

  Handles both authenticated users (one-click RSVP) and guests (email form).
  """
  use OhioElixirWeb, :live_view

  alias OhioElixir.Events
  alias OhioElixir.Events.Rsvp
  alias Phoenix.LiveView.JS

  on_mount {OhioElixirWeb.LiveUserAuth, :current_user}

  @impl true
  def mount(_params, session, socket) do
    event_id = session["event_id"]
    url_mode = parse_mode(session["mode"])
    current_user = socket.assigns[:current_user]

    {:ok, event} = Events.get_event(event_id, load: [:venue])
    existing_rsvp = get_existing_rsvp(current_user, event_id)

    attendance_mode =
      (existing_rsvp && existing_rsvp.attendance_mode) ||
        validate_mode_for_format(url_mode, event.format) ||
        default_attendance_mode(event.format)

    socket =
      socket
      |> assign(
        event_id: event_id,
        event: event,
        existing_rsvp: existing_rsvp,
        form: nil,
        submitting: false,
        attendance_mode: attendance_mode
      )
      |> maybe_build_form(existing_rsvp)

    {:ok, socket}
  end

  defp parse_mode("in_person"), do: :in_person
  defp parse_mode("online"), do: :online
  defp parse_mode(_), do: nil

  defp validate_mode_for_format(nil, _format), do: nil
  defp validate_mode_for_format(:in_person, format) when format in [:in_person, :hybrid], do: :in_person
  defp validate_mode_for_format(:online, format) when format in [:online, :hybrid], do: :online
  defp validate_mode_for_format(_mode, _format), do: nil

  defp default_attendance_mode(:online), do: :online
  defp default_attendance_mode(format) when format in [:in_person, :hybrid], do: :in_person
  defp default_attendance_mode(_), do: nil

  defp rsvp_status(nil), do: :not_rsvped
  defp rsvp_status(%{status: :confirmed}), do: :already_rsvped
  defp rsvp_status(%{status: :cancelled}), do: :cancelled
  defp rsvp_status(%{status: :waitlisted}), do: :waitlisted
  defp rsvp_status(_), do: :not_rsvped

  defp maybe_build_form(socket, nil = _existing_rsvp) do
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

  defp maybe_build_form(socket, _existing_rsvp), do: socket

  @impl true
  def handle_event("rsvp", _params, socket) do
    current_user = socket.assigns[:current_user]
    event_id = socket.assigns.event_id
    attendance_mode = socket.assigns.attendance_mode

    socket = assign(socket, submitting: true)

    input =
      if attendance_mode do
        %{attendance_mode: attendance_mode}
      else
        %{}
      end

    case Events.rsvp_to_event(event_id, input, actor: current_user) do
      {:ok, rsvp} ->
        {:noreply,
         assign(socket,
           existing_rsvp: rsvp,
           attendance_mode: rsvp.attendance_mode || attendance_mode,
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
    {:noreply, assign(socket, attendance_mode: String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("cancel_rsvp", _params, socket) do
    current_user = socket.assigns[:current_user]
    existing_rsvp = socket.assigns.existing_rsvp

    socket = assign(socket, submitting: true)

    case Events.cancel_rsvp(existing_rsvp, actor: current_user) do
      {:ok, _rsvp} ->
        {:noreply,
         socket
         |> assign(existing_rsvp: nil, submitting: false)
         |> maybe_build_form(nil)}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, format_error(error))
         |> assign(submitting: false)}
    end
  end

  @impl true
  def handle_event("update_attendance_mode", %{"mode" => mode}, socket) do
    current_user = socket.assigns[:current_user]
    existing_rsvp = socket.assigns.existing_rsvp
    new_mode = String.to_existing_atom(mode)

    socket = assign(socket, submitting: true)

    case Ash.update(existing_rsvp, %{attendance_mode: new_mode}, actor: current_user) do
      {:ok, updated_rsvp} ->
        {:noreply,
         assign(socket,
           existing_rsvp: updated_rsvp,
           attendance_mode: new_mode,
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
    attendance_mode = socket.assigns.attendance_mode

    params =
      params
      |> Map.put("event_id", socket.assigns.event_id)
      |> Map.put("attendance_mode", attendance_mode)

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, rsvp} ->
        {:noreply,
         assign(socket,
           existing_rsvp: rsvp,
           attendance_mode: rsvp.attendance_mode || attendance_mode,
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
    <div class="border border-base-300 p-6 sticky top-4 rsvp-component">
      <h2 class="text-lg font-bold mb-4">RSVP</h2>
      <div class="space-y-3">
        <%!-- Mode selector for hybrid events --%>
        <.attendance_mode_selector
          :if={@event.format == :hybrid}
          selected_mode={@attendance_mode}
          disabled={@submitting}
          has_rsvp={rsvp_status(@existing_rsvp) == :already_rsvped}
        />

        <%!-- Location info --%>
        <.attendance_mode_info
          mode={@attendance_mode}
          venue_name={@event.venue && @event.venue.name}
          meeting_url={@event.meeting_url}
        />

        <%!-- Action area --%>
        <div class="pt-3 border-t border-base-300">
          <.rsvp_action_content
            rsvp_status={rsvp_status(@existing_rsvp)}
            current_user={@current_user}
            submitting={@submitting}
            form={@form}
          />
        </div>
      </div>
    </div>
    """
  end

  defp attendance_mode_selector(assigns) do
    assigns =
      assigns
      |> Map.put_new(:disabled, false)
      |> Map.put_new(:has_rsvp, false)

    ~H"""
    <div class="flex gap-2">
      <button
        type="button"
        phx-click={if @has_rsvp, do: "update_attendance_mode", else: "select_mode"}
        phx-value-mode="in_person"
        disabled={@disabled}
        class={[
          "btn btn-sm flex-1",
          if(@selected_mode == :in_person, do: "btn-primary", else: "btn-outline")
        ]}
      >
        <.icon name="hero-map-pin" class="w-4 h-4" /> In Person
      </button>
      <button
        type="button"
        phx-click={if @has_rsvp, do: "update_attendance_mode", else: "select_mode"}
        phx-value-mode="online"
        disabled={@disabled}
        class={[
          "btn btn-sm flex-1",
          if(@selected_mode == :online, do: "btn-primary", else: "btn-outline")
        ]}
      >
        <.icon name="hero-video-camera" class="w-4 h-4" /> Online
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

  defp rsvp_action_content(assigns) do
    ~H"""
    <%= case @rsvp_status do %>
      <% :already_rsvped -> %>
        <div
          id="rsvp-confirmed"
          class="space-y-2"
          phx-remove={
            JS.transition(
              {"motion-safe:animate-out motion-safe:fade-out motion-safe:duration-150", "", ""},
              time: 150
            )
          }
        >
          <div class="flex items-center justify-center gap-2">
            <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
            <span class="font-medium">You're going!</span>
          </div>
          <button
            phx-click="cancel_rsvp"
            class="btn btn-ghost btn-sm w-full text-base-content/60"
            disabled={@submitting}
          >
            <%= if @submitting do %>
              <span class="loading loading-spinner loading-sm"></span>
            <% else %>
              Cancel RSVP
            <% end %>
          </button>
        </div>
      <% :waitlisted -> %>
        <div
          id="rsvp-waitlisted"
          class="text-center py-2"
          phx-remove={
            JS.transition(
              {"motion-safe:animate-out motion-safe:fade-out motion-safe:duration-150", "", ""},
              time: 150
            )
          }
        >
          <span class="badge badge-warning gap-2">
            <.icon name="hero-clock" class="w-4 h-4" /> Waitlisted
          </span>
          <p class="text-sm text-base-content/60 mt-1">We'll notify you if a spot opens up</p>
        </div>
      <% :cancelled -> %>
        <div
          id="rsvp-cancelled"
          class="text-center py-2"
          phx-remove={
            JS.transition(
              {"motion-safe:animate-out motion-safe:fade-out motion-safe:duration-150", "", ""},
              time: 150
            )
          }
        >
          <span class="text-base-content/70">RSVP cancelled</span>
        </div>
      <% :not_rsvped -> %>
        <%= if @current_user do %>
          <div
            id="rsvp-button"
            phx-remove={
              JS.transition(
                {"motion-safe:animate-out motion-safe:fade-out motion-safe:duration-150", "", ""},
                time: 150
              )
            }
          >
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
          </div>
        <% else %>
          <%= if @form do %>
            <.form
              for={@form}
              id="rsvp-form"
              phx-change="validate"
              phx-submit="submit"
              class="space-y-3"
              phx-remove={
                JS.transition(
                  {"motion-safe:animate-out motion-safe:fade-out motion-safe:duration-150", "", ""},
                  time: 150
                )
              }
            >
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
        <% end %>
      <% _ -> %>
        <%!-- Loading state renders nothing --%>
    <% end %>
    """
  end

  defp get_existing_rsvp(nil, _event_id), do: nil

  defp get_existing_rsvp(user, event_id) do
    case Events.get_rsvp_by_user_and_event(user.id, event_id) do
      {:ok, rsvp} -> rsvp
      _ -> nil
    end
  end
end
