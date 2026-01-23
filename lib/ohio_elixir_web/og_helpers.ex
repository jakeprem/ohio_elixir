defmodule OhioElixirWeb.OGHelpers do
  @moduledoc """
  Helper functions for setting Open Graph meta tag assigns.
  """

  import Plug.Conn, only: [assign: 3]

  alias OhioElixir.OGImage.{Source, Builder}

  @doc """
  Assigns Open Graph meta tag values to the connection.

  ## With a struct

  When given a struct implementing `OhioElixir.OGImage.Source`, automatically extracts
  title, description, image params, and type from the struct.

      conn
      |> assign_og(event)

      # For an event, this sets:
      # - og_title: event.title
      # - og_description: smart description with fallbacks
      # - og_image: URL with title + subtitle (date + venue)
      # - og_type: "event"

  ## With a keyword list

  When given a keyword list, keys are prefixed with `og_` when assigned.

      conn
      |> assign_og(title: "My Event", description: "Join us!", type: "event")

      # Equivalent to:
      conn
      |> assign(:og_title, "My Event")
      |> assign(:og_description, "Join us!")
      |> assign(:og_type, "event")

  Supported keys:

  - `:title` - Page title for OG
  - `:description` - Page description
  - `:image` - OG image URL
  - `:url` - Canonical URL
  - `:type` - OG type (website, article, event, etc.)
  """
  def assign_og(conn, source) when is_struct(source) do
    conn
    |> assign(:og_title, Source.og_title(source))
    |> assign(:og_description, Source.og_description(source))
    |> assign(:og_image, build_og_image_url(source))
    |> assign(:og_type, Source.og_type(source))
  end

  def assign_og(conn, params) when is_list(params) do
    Enum.reduce(params, conn, fn {key, val}, acc ->
      assign(acc, :"og_#{key}", val)
    end)
  end

  defp build_og_image_url(source) do
    source
    |> Source.og_image_params()
    |> Builder.build_url()
  end
end
