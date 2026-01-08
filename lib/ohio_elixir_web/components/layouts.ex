defmodule OhioElixirWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use OhioElixirWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :any, default: nil, doc: "the current user"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <.navbar current_user={@current_user} />
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
      <.footer />
    </div>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center border border-base-300 bg-base-200 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full bg-base-100 border border-base-300 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3 z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-60 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3 z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-60 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3 z-10"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-60 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  Renders the site navbar matching ohioelixir.com style.

  Auth state is handled client-side via data-auth-* attributes for cacheability.
  See assets/js/app.js for the Auth module that hydrates these elements.

  ## Examples

      <Layouts.navbar />
  """
  attr :current_user, :any, default: nil

  def navbar(assigns) do
    ~H"""
    <nav class="bg-base-100 border-b border-base-300 py-6">
      <div class="max-w-5xl mx-auto px-6 flex flex-col md:flex-row justify-between items-center">
        <h1 class="text-xl font-bold mb-4 md:mb-0">
          <a href="/" class="hover:text-primary transition-colors">Ohio Elixir</a>
        </h1>
        <div class="flex items-center space-x-8">
          <a href="/#about" class="text-base-content/70 hover:text-base-content transition-colors">
            About
          </a>
          <a href="/events" class="text-base-content/70 hover:text-base-content transition-colors">
            Events
          </a>
          <a href="#join" class="text-base-content/70 hover:text-base-content transition-colors">
            Join
          </a>
          <.theme_toggle />
          <div class="flex items-center gap-4">
            <%= if @current_user do %>
              <span class="text-base-content/70 text-sm">{@current_user.email}</span>
              <a href="/sign-out" class="btn btn-ghost btn-sm">Sign Out</a>
            <% else %>
              <a href="/sign-in" class="btn btn-primary btn-sm">Sign In</a>
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders the site footer with community links.

  ## Examples

      <Layouts.footer />
  """
  def footer(assigns) do
    ~H"""
    <footer id="join" class="bg-base-200 border-t border-base-300 py-16">
      <div class="max-w-5xl mx-auto px-6">
        <div class="max-w-2xl mx-auto text-center">
          <h3 class="text-2xl font-bold mb-4">Join Our Community</h3>
          <p class="text-base-content/60 mb-8">
            Connect with Ohio Elixir developers and stay updated on upcoming meetups.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center mb-8">
            <a
              href="https://discord.gg/JVVSwSNpK6"
              class="btn btn-primary"
              target="_blank"
              rel="noopener noreferrer"
            >
              Join Discord
            </a>
            <a
              href="https://github.com/ohio-elixir"
              class="btn btn-outline btn-primary"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
            <a
              href="https://bsky.app/profile/ohioelixir.bsky.social"
              class="btn btn-outline btn-primary"
              target="_blank"
              rel="noopener noreferrer"
            >
              Bluesky
            </a>
          </div>
          <div class="border-t border-base-300 pt-8">
            <p class="text-sm text-base-content/50">© 2025 Ohio Elixir Community</p>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
