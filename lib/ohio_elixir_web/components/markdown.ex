defmodule OhioElixirWeb.Markdown do
  @moduledoc """
  Provides secure Markdown rendering using MDEx.

  ## Security

  By default, all content is sanitized using ammonia to prevent XSS attacks.
  For trusted admin content, use `preset: :trusted` to skip sanitization.

  ## Usage

      <.markdown content={@event.description} />

      <.markdown content={@proposal.abstract} class="text-sm" />
  """
  use Phoenix.Component

  @base_options [
    extension: [
      strikethrough: true,
      table: true,
      autolink: true,
      tasklist: true,
      tagfilter: true
    ],
    parse: [
      relaxed_autolinks: true,
      smart: true
    ],
    render: [
      github_pre_lang: true,
      unsafe: true
    ],
    syntax_highlight: [
      formatter: :html_linked
    ]
  ]

  @doc """
  Converts markdown to HTML.

  Returns `{:ok, html}` or `{:error, reason}`.

  ## Options

  - `:default` - Full sanitization, safe for user content (default)
  - `:trusted` - No sanitization, for admin-only content
  """
  def to_html(markdown, preset \\ :default)
  def to_html(nil, _preset), do: {:ok, ""}
  def to_html("", _preset), do: {:ok, ""}

  def to_html(markdown, :default) when is_binary(markdown) do
    MDEx.to_html(
      markdown,
      Keyword.put(@base_options, :sanitize, MDEx.Document.default_sanitize_options())
    )
  end

  def to_html(markdown, :trusted) when is_binary(markdown) do
    MDEx.to_html(markdown, @base_options)
  end

  @doc """
  Converts markdown to HTML, raising on error.
  """
  def to_html!(markdown, preset \\ :default)
  def to_html!(nil, _preset), do: ""
  def to_html!("", _preset), do: ""

  def to_html!(markdown, preset) when is_binary(markdown) do
    case to_html(markdown, preset) do
      {:ok, html} -> html
      {:error, reason} -> raise "Failed to convert markdown: #{inspect(reason)}"
    end
  end

  @doc """
  Renders markdown content as HTML with Tailwind typography styling.

  ## Attributes

  - `content` - Required. The raw markdown string to render.
  - `class` - Optional. Additional CSS classes for the wrapper div.
  - `preset` - Optional. Security preset (`:default` or `:trusted`). Defaults to `:default`.

  ## Examples

      <.markdown content={@event.description} />

      <.markdown content={@proposal.abstract} class="text-sm" preset={:default} />
  """
  attr :content, :string, required: true
  attr :class, :string, default: nil
  attr :preset, :atom, default: :default, values: [:default, :trusted]

  def markdown(assigns) do
    html = to_html!(assigns.content, assigns.preset)
    assigns = assign(assigns, :html, html)

    ~H"""
    <div class={["prose prose-sm max-w-none", @class]}>
      {Phoenix.HTML.raw(@html)}
    </div>
    """
  end
end
