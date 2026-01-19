defmodule OhioElixirWeb.Components.Turnstile do
  @moduledoc """
  Cloudflare Turnstile component.

  Renders the Turnstile widget which populates a hidden form field with the
  verification token. The token is then verified server-side on form submission.

  Usage:

      <.turnstile id="my-turnstile" field_name="cf-turnstile-response" />

  The token will be available in form params under the specified field name.
  """
  use Phoenix.Component

  alias OhioElixir.Turnstile
  alias Phoenix.LiveView.ColocatedHook

  @doc """
  Renders a Cloudflare Turnstile widget.

  ## Attributes

    * `id` - Required. Unique ID for the widget.
    * `field_name` - Name for the hidden input field. Defaults to "cf-turnstile-response".

  """
  attr :id, :string, required: true
  attr :field_name, :string, default: "cf-turnstile-response"

  def turnstile(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook=".Turnstile"
      phx-update="ignore"
      data-sitekey={Turnstile.site_key()}
      data-field-name={@field_name}
    >
    </div>
    <script :type={ColocatedHook} name=".Turnstile">
      export default {
        mounted() {
          this.widgetId = null;
          this.loadAndRender();
        },

        destroyed() {
          if (this.widgetId && window.turnstile) {
            window.turnstile.remove(this.widgetId);
          }
        },

        loadAndRender() {
          if (window.turnstile) {
            this.renderWidget();
          } else {
            const script = document.createElement('script');
            script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
            script.async = true;
            script.onload = () => this.renderWidget();
            document.head.appendChild(script);
          }
        },

        renderWidget() {
          const sitekey = this.el.dataset.sitekey;
          const fieldName = this.el.dataset.fieldName;
          const form = this.el.closest('form');

          this.widgetId = window.turnstile.render(this.el, {
            sitekey: sitekey,
            callback: (token) => {
              if (form) {
                let input = form.querySelector(`input[name="${fieldName}"]`);
                if (!input) {
                  input = document.createElement('input');
                  input.type = 'hidden';
                  input.name = fieldName;
                  form.appendChild(input);
                }
                input.value = token;
              }
            },
            'error-callback': () => {
              if (form) {
                const input = form.querySelector(`input[name="${fieldName}"]`);
                if (input) input.value = '';
              }
            },
            'expired-callback': () => {
              if (form) {
                const input = form.querySelector(`input[name="${fieldName}"]`);
                if (input) input.value = '';
              }
            }
          });
        }
      }
    </script>
    """
  end
end
