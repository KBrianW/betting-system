# This migration is now redundant because cancelled_at is added in a later migration.
# No changes needed here. Safe to drop or leave empty.
defmodule BetZone.Repo.Migrations.AddCancelledAtToPlacedBets do
  use Ecto.Migration

  def change do
    # No-op: cancelled_at handled in a later migration
  end
end
