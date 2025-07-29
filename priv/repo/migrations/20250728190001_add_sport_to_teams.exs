defmodule BetZone.Repo.Migrations.AddSportToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :sport_id, references(:sports, on_delete: :nothing)
    end

    create index(:teams, [:sport_id])
  end
end
