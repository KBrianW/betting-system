defmodule BetZone.Repo.Migrations.UpdateTeamsWithDefaultSport do
  use Ecto.Migration

  def up do
    # Update existing teams to use the first available sport (default sport)
    execute """
    UPDATE teams
    SET sport_id = (SELECT id FROM sports ORDER BY id LIMIT 1)
    WHERE sport_id IS NULL
    """
  end

  def down do
    # This migration is safe to reverse - it just sets sport_id to NULL
    execute """
    UPDATE teams
    SET sport_id = NULL
    WHERE sport_id = (SELECT id FROM sports ORDER BY id LIMIT 1)
    """
  end
end
