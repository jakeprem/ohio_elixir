defmodule OhioElixirWeb.PageController do
  use OhioElixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
