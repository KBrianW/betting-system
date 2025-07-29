defmodule BetZone.Repo.Migrations.AddSportToGames do
  use Ecto.Migration

  def up do
    # First, add the column as nullable
    alter table(:games) do
      add :sport_id, references(:sports, on_delete: :delete_all), null: true
    end

    # Create a default sport if none exists
    execute """
    INSERT INTO sports (name, emoji, active, inserted_at, updated_at)
    SELECT 'Default Sport', '🎯', true, NOW(), NOW()
    WHERE NOT EXISTS (SELECT 1 FROM sports LIMIT 1)
    """

    # Update existing games to use the first available sport
    execute """
    UPDATE games
    SET sport_id = (SELECT id FROM sports ORDER BY id LIMIT 1)
    WHERE sport_id IS NULL
    """

    # Make the column non-nullable
    execute "ALTER TABLE games ALTER COLUMN sport_id SET NOT NULL"

    # Create index
    create index(:games, [:sport_id])
  end

  def down do
    drop index(:games, [:sport_id])

    alter table(:games) do
      remove :sport_id
    end
  end
end
