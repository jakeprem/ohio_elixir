defmodule OhioElixir.OGImage.Builder do
  @moduledoc """
  Builds signed URLs for dynamically generated OG images.

  URLs are signed with HMAC to prevent abuse of the /og endpoint.
  """

  alias OhioElixir.OGImage.HMAC

  # Bump this when you change the og-generator.tsx design
  # to bust social media caches and force re-fetching
  @og_version "4"

  @doc """
  Builds a signed URL for an OG image served by our Phoenix app.

  Includes a version parameter for cache busting and an HMAC signature
  to prevent unauthorized image generation.

  ## Example

      iex> build_url(%{title: "Elixir Meetup", subtitle: "January 15, 2026"})
      "https://ohioelixir.com/og/image.png?title=Elixir+Meetup&subtitle=January+15%2C+2026&v=1&sig=abc123"
  """
  def build_url(params) when is_list(params), do: build_url(Map.new(params))

  def build_url(params) when is_map(params) do
    # Filter out nil/empty values and add version
    clean_params =
      params
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()
      |> Map.put(:v, @og_version)

    signature = HMAC.sign(clean_params)
    query_string = URI.encode_query(Map.put(clean_params, :sig, signature))

    "#{OhioElixirWeb.Endpoint.url()}/og/image.png?#{query_string}"
  end
end
