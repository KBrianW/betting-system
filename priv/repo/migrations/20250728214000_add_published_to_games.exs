defmodule BetZone.Repo.Migrations.AddPublishedToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :published, :boolean, default: true, null: false
    end

    create index(:games, [:published])
  end
end
