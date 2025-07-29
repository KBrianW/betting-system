defmodule BetZone.Repo.Migrations.RenameDefaultSportToFootball do
  use Ecto.Migration

  def up do
    # Update the default sport name and emoji to Football
    execute """
    UPDATE sports
    SET name = 'Football', emoji = '⚽'
    WHERE name = 'Default Sport'
    """
  end

  def down do
    # Revert back to Default Sport
    execute """
    UPDATE sports
    SET name = 'Default Sport', emoji = '🎯'
    WHERE name = 'Football' AND emoji = '⚽'
    """
  end
end
