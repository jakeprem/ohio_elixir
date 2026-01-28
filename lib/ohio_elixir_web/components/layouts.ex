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
  Renders the GoatCounter analytics script tag.

  Configuration is pulled from :ohio_elixir, :goatcounter config key:
  - url: The GoatCounter endpoint URL
  - allow_local: Whether to track localhost (useful for dev)
  """
  def goatcounter_script(assigns) do
    config = Application.get_env(:ohio_elixir, :goatcounter, [])
    url = Keyword.get(config, :url)
    allow_local = Keyword.get(config, :allow_local, false)

    settings =
      if allow_local,
        do: Jason.encode!(%{allow_local: true}),
        else: "{}"

    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:settings, settings)

    ~H"""
    <script
      :if={@url}
      data-goatcounter={@url}
      data-goatcounter-settings={@settings}
      async
      src={~p"/js/goatcounter.js"}
    >
    </script>
    """
  end

  @doc """
  Renders Open Graph meta tags for social sharing.

  Supports the following assigns with fallback chain:
  - og_title: Falls back to page_title, then site default
  - og_description: Falls back to site default
  - og_image: Falls back to default site image
  - og_url: Current request URL
  - og_type: Defaults to "website"

  ## Examples

      # In root.html.heex
      <.og_tags
        og_title={assigns[:og_title]}
        og_description={assigns[:og_description]}
        og_image={assigns[:og_image]}
        og_url={assigns[:og_url]}
        og_type={assigns[:og_type]}
        page_title={assigns[:page_title]}
        conn={assigns[:conn]}
      />
  """
  attr :og_title, :string, default: nil
  attr :og_description, :string, default: nil
  attr :og_image, :string, default: nil
  attr :og_url, :string, default: nil
  attr :og_type, :string, default: nil
  attr :page_title, :string, default: nil
  attr :conn, :any, default: nil

  def og_tags(assigns) do
    site_name = "Ohio Elixir"

    default_description =
      "Join Ohio's community of Elixir developers. Monthly meetups, show & tell sessions, and collaborative learning."

    # Build the actual values with fallback chain
    title = assigns.og_title || assigns.page_title || site_name

    full_title =
      if title == site_name, do: site_name, else: "#{title} · #{site_name}"

    description = assigns.og_description || default_description
    image = assigns.og_image || default_og_image_url()
    og_type = assigns.og_type || "website"

    # Get current URL from conn
    url = assigns.og_url || current_url_from_conn(assigns.conn)

    assigns =
      assigns
      |> assign(:full_title, full_title)
      |> assign(:description, description)
      |> assign(:image, image)
      |> assign(:url, url)
      |> assign(:og_type, og_type)
      |> assign(:site_name, site_name)

    ~H"""
    <meta property="og:type" content={@og_type} />
    <meta property="og:url" content={@url} />
    <meta property="og:title" content={@full_title} />
    <meta property="og:description" content={@description} />
    <meta property="og:image" content={@image} />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:site_name" content={@site_name} />
    <meta property="og:locale" content="en_US" />

    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:url" content={@url} />
    <meta name="twitter:title" content={@full_title} />
    <meta name="twitter:description" content={@description} />
    <meta name="twitter:image" content={@image} />

    <meta name="description" content={@description} />
    """
  end

  defp default_og_image_url do
    OhioElixir.OGImage.Builder.build_url(%{
      title: "Ohio Elixir",
      subtitle: "Ohio's community of Elixir developers"
    })
  end

  defp current_url_from_conn(nil), do: OhioElixirWeb.Endpoint.url()

  defp current_url_from_conn(conn) do
    OhioElixirWeb.Endpoint.url() <> conn.request_path
  end

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
  Renders a user avatar with Gravatar support and initials fallback.
  """
  attr :user, :any, required: true
  attr :class, :string, default: "w-10"

  def user_avatar(assigns) do
    ~H"""
    <%= if @user.preferences && @user.preferences.use_gravatar do %>
      <div class="avatar">
        <div class={"#{@class} rounded-full"}>
          <img
            src={gravatar_url(@user.email)}
            alt={user_initials(@user)}
            onerror={"this.parentElement.parentElement.outerHTML = '<div class=\"avatar avatar-placeholder\"><div class=\"bg-primary text-primary-content #{@class} rounded-full\"><span>' + '#{user_initials(@user)}' + '</span></div></div>'"}
          />
        </div>
      </div>
    <% else %>
      <div class="avatar avatar-placeholder">
        <div class={"bg-primary text-primary-content #{@class} rounded-full"}>
          <span>{user_initials(@user)}</span>
        </div>
      </div>
    <% end %>
    """
  end

  defp gravatar_url(email) do
    hash =
      :crypto.hash(:md5, String.downcase(String.trim(to_string(email))))
      |> Base.encode16(case: :lower)

    "https://www.gravatar.com/avatar/#{hash}?d=404&s=80"
  end

  defp user_initials(user) do
    cond do
      user.first_name && user.last_name ->
        String.first(user.first_name) <> String.first(user.last_name)

      user.first_name ->
        String.first(user.first_name)

      true ->
        user.email |> to_string() |> String.first() |> String.upcase()
    end
  end

  defp display_name(user) do
    cond do
      user.first_name && user.last_name ->
        "#{user.first_name} #{user.last_name}"

      user.first_name ->
        user.first_name

      true ->
        user.email |> to_string() |> String.split("@") |> hd()
    end
  end

  @doc """
  Renders the user menu dropdown for desktop navigation.
  """
  attr :current_user, :any, default: nil

  def user_menu(assigns) do
    ~H"""
    <%= if @current_user do %>
      <div class="dropdown dropdown-end">
        <div tabindex="0" role="button" class="cursor-pointer">
          <.user_avatar user={@current_user} class="w-10" />
        </div>
        <ul
          tabindex="0"
          class="dropdown-content menu bg-base-100 rounded-box z-50 w-56 p-2 shadow-lg border border-base-300 mt-2"
        >
          <li class="menu-title px-4 py-2 text-left">
            <div class="font-medium text-base-content">{display_name(@current_user)}</div>
            <div class="text-xs text-base-content/60 font-normal">{@current_user.email}</div>
          </li>
          <li>
            <a href="/profile" class="flex items-center gap-2">
              <.icon name="hero-user" class="size-4" /> Profile
            </a>
          </li>
          <li>
            <a href="/sign-out" class="flex items-center gap-2">
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sign Out
            </a>
          </li>
          <li class="mt-2 pt-2 border-t border-base-300">
            <div class="flex items-center justify-between hover:bg-transparent cursor-default">
              <span class="text-sm text-base-content/70">Theme</span>
              <.theme_toggle />
            </div>
          </li>
        </ul>
      </div>
    <% else %>
      <div class="dropdown dropdown-end">
        <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
          <.icon name="hero-bars-3" class="size-5" />
        </div>
        <ul
          tabindex="0"
          class="dropdown-content menu bg-base-100 rounded-box z-50 w-56 p-2 shadow-lg border border-base-300 mt-2"
        >
          <li>
            <a href="/sign-in" class="flex items-center gap-2">
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sign In
            </a>
          </li>
          <li class="mt-2 pt-2 border-t border-base-300">
            <div class="flex items-center justify-between hover:bg-transparent cursor-default">
              <span class="text-sm text-base-content/70">Theme</span>
              <.theme_toggle />
            </div>
          </li>
        </ul>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders the site navbar with responsive drawer for mobile.
  """
  attr :current_user, :any, default: nil

  def navbar(assigns) do
    ~H"""
    <div class="drawer drawer-end">
      <input id="mobile-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col">
        <!-- Desktop navbar (hidden on mobile) -->
        <nav class="hidden md:block bg-base-100 border-b border-base-300">
          <div class="max-w-5xl mx-auto px-6 py-4 flex justify-between items-center">
            <a
              href="/"
              data-instant
              class="flex items-center gap-2 hover:opacity-80 transition-opacity"
            >
              <img src="/images/logo.webp" alt="Ohio Elixir" class="h-10 w-auto" />
              <span class="text-xl font-bold">Ohio Elixir</span>
            </a>
            <div class="flex items-center gap-6">
              <a
                href="/#about"
                class="text-base-content/70 hover:text-base-content transition-colors"
              >
                About
              </a>
              <a
                href="/events"
                data-instant
                class="text-base-content/70 hover:text-base-content transition-colors"
              >
                Events
              </a>
              <a href="#join" class="text-base-content/70 hover:text-base-content transition-colors">
                Join
              </a>
              <.user_menu current_user={@current_user} />
            </div>
          </div>
        </nav>
        <!-- Mobile navbar (visible on mobile only) -->
        <nav class="md:hidden bg-base-100 border-b border-base-300">
          <div class="px-4 py-3 flex justify-between items-center">
            <a
              href="/"
              data-instant
              class="flex items-center hover:opacity-80 transition-opacity"
            >
              <img src="/images/logo.webp" alt="Ohio Elixir" class="h-10 w-auto" />
            </a>
            <label for="mobile-drawer" class="btn btn-ghost btn-square btn-sm">
              <.icon name="hero-bars-3" class="size-6" />
            </label>
          </div>
        </nav>
      </div>
      <!-- Mobile drawer sidebar (opens from right) -->
      <div class="drawer-side z-50">
        <label for="mobile-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <div class="bg-base-200 min-h-full w-80 p-4">
          <div class="flex justify-between items-center mb-6">
            <label for="mobile-drawer" class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-x-mark" class="size-5" />
            </label>
            <span class="text-lg font-bold">Menu</span>
          </div>

          <ul class="menu p-0 space-y-1">
            <li>
              <a href="/#about" class="text-base">About</a>
            </li>
            <li>
              <a href="/events" data-instant class="text-base">Events</a>
            </li>
            <li>
              <a href="#join" class="text-base">Join</a>
            </li>
          </ul>

          <div class="divider"></div>

          <%= if @current_user do %>
            <div class="flex items-center gap-3 mb-4 px-2">
              <.user_avatar user={@current_user} class="w-12" />
              <div>
                <div class="font-medium">{display_name(@current_user)}</div>
                <div class="text-sm text-base-content/60">{@current_user.email}</div>
              </div>
            </div>
            <ul class="menu p-0 space-y-1">
              <li>
                <a href="/profile" class="text-base">
                  <.icon name="hero-user" class="size-5" /> Profile
                </a>
              </li>
              <li>
                <a href="/sign-out" class="text-base">
                  <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Sign Out
                </a>
              </li>
            </ul>
          <% else %>
            <div class="px-2">
              <a href="/sign-in" class="btn btn-primary w-full">Sign In</a>
            </div>
          <% end %>

          <div class="divider"></div>

          <div class="flex items-center justify-between px-2">
            <span class="text-sm text-base-content/70">Theme</span>
            <.theme_toggle />
          </div>
        </div>
      </div>
    </div>
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
            <p class="text-sm text-base-content/50">© <%= Date.utc_today().year %> Ohio Elixir Community</p>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
