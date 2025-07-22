defmodule BetZone.Repo.Migrations.AddSportToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :sport, :string
    end
  end
end
