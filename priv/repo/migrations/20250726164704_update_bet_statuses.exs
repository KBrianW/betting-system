defmodule BetZone.Repo.Migrations.UpdateBetStatuses do
  use Ecto.Migration

  def change do
    # This migration is intentionally left empty to resolve duplicate_column error for :result
    # The :result column already exists in the schema.
  end
end
