defmodule BetZone.Repo.Migrations.CreateSports do
  use Ecto.Migration

  def change do
    create table(:sports) do
      add :name, :string, null: false
      add :emoji, :string
      add :active, :boolean, default: true

      timestamps()
    end

    create unique_index(:sports, [:name])
  end
end
