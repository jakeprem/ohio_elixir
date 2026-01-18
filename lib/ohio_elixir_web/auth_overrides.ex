defmodule OhioElixirWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.Components.Banner do
    set :root_class, "flex items-center justify-center gap-4 py-6 px-12"
    set :image_url, "/images/logo.webp"
    set :image_class, "h-20 w-auto"
    set :dark_image_url, nil
    set :text, "Ohio Elixir"
    set :text_class, "text-4xl font-bold"
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :show_banner, true
  end
end
