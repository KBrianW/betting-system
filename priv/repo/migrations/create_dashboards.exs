defmodule BetZone.Repo.Migrations.CreateDashboards do
  use Ecto.Migration

  def change do
    create table(:dashboards) do
      timestamps(type: :utc_datetime)
    end
  end
end
