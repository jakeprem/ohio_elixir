defmodule OhioElixirWeb.OGImageController do
  use OhioElixirWeb, :controller

  alias OhioElixir.OGImage.HMAC

  @cache_max_age 31_536_000

  @doc """
  Generates and serves an OG image.

  Validates the HMAC signature, then calls a local Bun script to generate
  the PNG. Serves with long cache headers since images are immutable per param set.
  """
  def show(conn, params) do
    signature = params["sig"]

    # Extract params without signature for verification
    image_params =
      params
      |> Map.drop(["sig"])
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    if HMAC.verify(image_params, signature || "") do
      serve_og_image(conn, image_params)
    else
      conn
      |> put_status(403)
      |> text("Invalid signature")
    end
  end

  defp serve_og_image(conn, params) do
    case generate_og_image(params) do
      {:ok, png_bytes} ->
        conn
        |> put_resp_content_type("image/png")
        |> put_resp_header("cache-control", "public, max-age=#{@cache_max_age}, immutable")
        |> send_resp(200, png_bytes)

      {:error, reason} ->
        conn
        |> put_status(500)
        |> text("Image generation failed: #{reason}")
    end
  end

  defp generate_og_image(%{title: nil}), do: {:error, "title is required"}

  defp generate_og_image(params) do
    script_path = script_path()
    # Only pass title and subtitle to the script, not version
    json_params = Jason.encode!(%{title: params[:title], subtitle: params[:subtitle]})

    case System.cmd("bun", ["run", script_path, json_params],
           stderr_to_stdout: false,
           cd: Path.dirname(script_path)
         ) do
      {png_bytes, 0} when byte_size(png_bytes) > 0 ->
        {:ok, png_bytes}

      {"", 0} ->
        {:error, "No output from image generator"}

      {output, exit_code} ->
        {:error, "Exit code #{exit_code}: #{output}"}
    end
  end

  defp script_path do
    Application.app_dir(:ohio_elixir, "priv/bun-scripts/og-generator.tsx")
  end
end
