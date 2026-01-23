defmodule OhioElixirWeb.Auth.SignInLive do
  use OhioElixirWeb, :live_view

  alias AshAuthentication.Info
  alias AshPhoenix.Form
  alias OhioElixir.Accounts.User
  alias OhioElixir.Turnstile

  import OhioElixirWeb.Components.Turnstile

  @impl true
  def mount(_params, _session, socket) do
    strategy = Info.strategy!(User, :magic_link)

    form =
      User
      |> Form.for_action(strategy.request_action_name,
        domain: OhioElixir.Accounts,
        as: "user",
        id: "user-magic-link-request",
        context: %{
          strategy: strategy,
          private: %{ash_authentication?: true}
        }
      )
      |> to_form()

    socket =
      socket
      |> assign(
        form: form,
        turnstile_error: nil,
        submitting: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      socket.assigns.form.source
      |> Form.validate(params, errors: false)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event(
        "submit",
        %{"user" => params, "cf-turnstile-response" => turnstile_token},
        socket
      ) do
    socket = assign(socket, submitting: true, turnstile_error: nil)

    case Turnstile.verify(turnstile_token) do
      :ok ->
        submit_magic_link_request(socket, params)

      {:error, _reason} ->
        {:noreply,
         assign(socket,
           turnstile_error: "Verification failed. Please try again.",
           submitting: false
         )}
    end
  end

  def handle_event("submit", %{"user" => _params}, socket) do
    {:noreply,
     assign(socket,
       turnstile_error: "Please complete the verification.",
       submitting: false
     )}
  end

  defp submit_magic_link_request(socket, params) do
    case Form.submit(socket.assigns.form.source, params: params) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Check your email for a sign-in link.")
         |> redirect(to: ~p"/")}

      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Check your email for a sign-in link.")
         |> redirect(to: ~p"/")}

      {:error, form} ->
        {:noreply,
         assign(socket,
           form: to_form(form),
           submitting: false
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    <div class="grid h-screen place-items-center bg-base-100">
      <div class="flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none lg:px-20 xl:px-24">
        <div class="mx-auto w-full max-w-sm lg:w-96">
          <%!-- Banner --%>
          <div class="w-full flex justify-center py-2">
            <a href="/" class="flex items-center justify-center gap-4">
              <img src="/images/logo.webp" alt="Ohio Elixir" class="h-20 w-auto" />
              <span class="text-4xl font-bold">Ohio Elixir</span>
            </a>
          </div>

          <%!-- Form --%>
          <div class="mt-4 mb-4">
            <.form
                for={@form}
                id="magic-link-form"
                phx-change="validate"
                phx-submit="submit"
              >
                <div class="mt-2 mb-2">
                  <label class="block text-sm font-medium text-base-content mb-1">
                    Email
                  </label>
                  <input
                    type="email"
                    name={@form[:email].name}
                    value={@form[:email].value}
                    class="input w-full"
                    placeholder="you@example.com"
                    required
                    autocomplete="email"
                  />
                </div>

                <div class="flex flex-col items-center my-4">
                  <.turnstile id="sign-in-turnstile" />
                  <%= if @turnstile_error do %>
                    <p class="text-error text-sm mt-2">{@turnstile_error}</p>
                  <% end %>
                </div>

                <button
                  type="submit"
                  class="btn btn-primary btn-block mt-4 mb-4"
                  disabled={@submitting}
                >
                  <%= if @submitting do %>
                    Requesting ...
                  <% else %>
                    Sign in
                  <% end %>
                </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
