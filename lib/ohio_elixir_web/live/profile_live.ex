defmodule OhioElixirWeb.ProfileLive do
  @moduledoc """
  LiveView for editing user profile and preferences.
  """
  use OhioElixirWeb, :live_view

  on_mount {OhioElixirWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    form =
      current_user
      |> AshPhoenix.Form.for_update(:update_profile,
        as: "user",
        actor: current_user
      )
      |> to_form()

    socket =
      assign(socket,
        page_title: "Profile",
        form: form
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, updated_user} ->
        # Rebuild the form with the updated user
        form =
          updated_user
          |> AshPhoenix.Form.for_update(:update_profile,
            as: "user",
            actor: updated_user
          )
          |> to_form()

        {:noreply,
         socket
         |> assign(form: form, current_user: updated_user)
         |> put_flash(:info, "Profile updated successfully")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <header class="border-b border-base-300 py-8">
        <div class="max-w-2xl mx-auto px-6">
          <h1 class="text-3xl font-bold">Profile</h1>
          <p class="text-base-content/60 mt-2">Manage your profile information and preferences</p>
        </div>
      </header>

      <div class="max-w-2xl mx-auto px-6 py-8">
        <.form for={@form} id="profile-form" phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="border border-base-300 rounded-lg p-6 space-y-4">
            <h2 class="text-lg font-bold">Profile Information</h2>
            <p class="text-sm text-base-content/60">Your name will be displayed in the navigation and on your RSVPs.</p>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:first_name]} label="First Name" placeholder="Optional" />
              <.input field={@form[:last_name]} label="Last Name" placeholder="Optional" />
            </div>

            <div class="pt-2">
              <label class="text-sm font-medium">Email</label>
              <p class="text-base-content/60 mt-1">{@current_user.email}</p>
              <p class="text-xs text-base-content/40 mt-1">Email cannot be changed</p>
            </div>
          </div>

          <div class="border border-base-300 rounded-lg p-6 space-y-4">
            <h2 class="text-lg font-bold">Preferences</h2>

            <.inputs_for :let={pref_form} field={@form[:preferences]}>
              <div class="flex items-start gap-4">
                <div class="flex-1">
                  <.input
                    field={pref_form[:use_gravatar]}
                    type="checkbox"
                    label="Use Gravatar for avatar"
                  />
                  <p class="text-sm text-base-content/60 mt-1">
                    When enabled, your avatar will be fetched from
                    <a href="https://gravatar.com" target="_blank" class="link link-primary">Gravatar</a>
                    based on your email. When disabled, your initials will be shown instead.
                  </p>
                </div>
                <div class="flex-shrink-0">
                  <Layouts.user_avatar user={preview_user(@form, pref_form, @current_user)} class="w-16" />
                </div>
              </div>
            </.inputs_for>
          </div>

          <div class="flex gap-4 justify-end">
            <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
              Save Changes
            </button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  # Create a preview user struct with current form values for avatar preview
  defp preview_user(form, pref_form, current_user) do
    first_name = Phoenix.HTML.Form.input_value(form, :first_name)
    last_name = Phoenix.HTML.Form.input_value(form, :last_name)

    use_gravatar = Phoenix.HTML.Form.input_value(pref_form, :use_gravatar)

    # Normalize use_gravatar to boolean
    use_gravatar =
      case use_gravatar do
        true -> true
        "true" -> true
        _ -> false
      end

    %{
      email: current_user.email,
      first_name: first_name,
      last_name: last_name,
      preferences: %{use_gravatar: use_gravatar}
    }
  end
end
