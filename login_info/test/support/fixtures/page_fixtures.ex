defmodule BettingSystem.PageFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BettingSystem.Page` context.
  """

  @doc """
  Generate a dashboard.
  """
  def dashboard_fixture(attrs \\ %{}) do
    {:ok, dashboard} =
      attrs
      |> Enum.into(%{

      })
      |> BettingSystem.Page.create_dashboard()

    dashboard
  end
end
