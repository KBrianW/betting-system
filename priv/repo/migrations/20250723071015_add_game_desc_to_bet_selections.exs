defmodule BetZone.Repo.Migrations.AddGameDescToBetSelections do
  use Ecto.Migration

  def change do
    alter table(:bet_selections) do
      add :game_desc, :string
    end
  end
end
