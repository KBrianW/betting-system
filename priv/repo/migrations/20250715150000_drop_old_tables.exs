defmodule BetZone.Repo.Migrations.DropOldTables do
  use Ecto.Migration

  def up do
    # Drop tables only if they exist
    execute "DROP TABLE IF EXISTS transactions CASCADE"
    execute "DROP TABLE IF EXISTS bets CASCADE"
    execute "DROP TABLE IF EXISTS draft_bets CASCADE"
  end

  def down do
    # We don't want to recreate these tables as they're being replaced
    # with better structures
  end
end
