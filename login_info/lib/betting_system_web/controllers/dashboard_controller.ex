defmodule BettingSystemWeb.DashboardController do
  use BettingSystemWeb, :controller

  alias BettingSystem.Page
  alias BettingSystem.Page.Dashboard

  def index(conn, _params) do
    dashboards = Page.list_dashboards()
    render(conn, :index, dashboards: dashboards)
  end

  def new(conn, _params) do
    changeset = Page.change_dashboard(%Dashboard{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"dashboard" => dashboard_params}) do
    case Page.create_dashboard(dashboard_params) do
      {:ok, dashboard} ->
        conn
        |> put_flash(:info, "Dashboard created successfully.")
        |> redirect(to: ~p"/dashboards/#{dashboard}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    dashboard = Page.get_dashboard!(id)
    render(conn, :show, dashboard: dashboard)
  end

  def edit(conn, %{"id" => id}) do
    dashboard = Page.get_dashboard!(id)
    changeset = Page.change_dashboard(dashboard)
    render(conn, :edit, dashboard: dashboard, changeset: changeset)
  end

  def update(conn, %{"id" => id, "dashboard" => dashboard_params}) do
    dashboard = Page.get_dashboard!(id)

    case Page.update_dashboard(dashboard, dashboard_params) do
      {:ok, dashboard} ->
        conn
        |> put_flash(:info, "Dashboard updated successfully.")
        |> redirect(to: ~p"/dashboards/#{dashboard}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, dashboard: dashboard, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    dashboard = Page.get_dashboard!(id)
    {:ok, _dashboard} = Page.delete_dashboard(dashboard)

    conn
    |> put_flash(:info, "Dashboard deleted successfully.")
    |> redirect(to: ~p"/dashboards")
  end
end
