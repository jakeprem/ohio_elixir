defmodule OhioElixirWeb.PageControllerTest do
  use OhioElixirWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Ohio Elixir"
    assert html_response(conn, 200) =~ "Upcoming Events"
  end
end
