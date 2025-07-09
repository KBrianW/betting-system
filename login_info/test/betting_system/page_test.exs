defmodule BettingSystem.PageTest do
  use BettingSystem.DataCase

  alias BettingSystem.Page

  describe "dashboards" do
    alias BettingSystem.Page.Dashboard

    import BettingSystem.PageFixtures

    @invalid_attrs %{}

    test "list_dashboards/0 returns all dashboards" do
      dashboard = dashboard_fixture()
      assert Page.list_dashboards() == [dashboard]
    end

    test "get_dashboard!/1 returns the dashboard with given id" do
      dashboard = dashboard_fixture()
      assert Page.get_dashboard!(dashboard.id) == dashboard
    end

    test "create_dashboard/1 with valid data creates a dashboard" do
      valid_attrs = %{}

      assert {:ok, %Dashboard{} = dashboard} = Page.create_dashboard(valid_attrs)
    end

    test "create_dashboard/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Page.create_dashboard(@invalid_attrs)
    end

    test "update_dashboard/2 with valid data updates the dashboard" do
      dashboard = dashboard_fixture()
      update_attrs = %{}

      assert {:ok, %Dashboard{} = dashboard} = Page.update_dashboard(dashboard, update_attrs)
    end

    test "update_dashboard/2 with invalid data returns error changeset" do
      dashboard = dashboard_fixture()
      assert {:error, %Ecto.Changeset{}} = Page.update_dashboard(dashboard, @invalid_attrs)
      assert dashboard == Page.get_dashboard!(dashboard.id)
    end

    test "delete_dashboard/1 deletes the dashboard" do
      dashboard = dashboard_fixture()
      assert {:ok, %Dashboard{}} = Page.delete_dashboard(dashboard)
      assert_raise Ecto.NoResultsError, fn -> Page.get_dashboard!(dashboard.id) end
    end

    test "change_dashboard/1 returns a dashboard changeset" do
      dashboard = dashboard_fixture()
      assert %Ecto.Changeset{} = Page.change_dashboard(dashboard)
    end
  end
end
