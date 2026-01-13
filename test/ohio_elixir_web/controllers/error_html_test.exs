defmodule OhioElixirWeb.ErrorHTMLTest do
  use OhioElixirWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html with custom styled page" do
    html = render_to_string(OhioElixirWeb.ErrorHTML, "404", "html", [])
    assert html =~ "404"
    assert html =~ "Page Not Found"
    assert html =~ "Ohio Elixir"
  end

  test "renders 500.html" do
    assert render_to_string(OhioElixirWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
