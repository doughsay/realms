defmodule RealmsWeb.PageController do
  use RealmsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
