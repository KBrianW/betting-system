defmodule BetZoneWeb.ErrorJSONTest do
  use BetZoneWeb.ConnCase, async: true

  test "renders 404" do
    assert BetZoneWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert BetZoneWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
