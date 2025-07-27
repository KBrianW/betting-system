# priv/repo/migrations/[timestamp]_update_bet_statuses_and_add_result.exs
defmodule BetZone.Repo.Migrations.UpdateBetStatusesAndAddResult do
  use Ecto.Migration

  def change do
    # Add the new result column (cancelled_at already exists, so do not add again)
    alter table(:placed_bets) do
      add :result, :string
      # add :cancelled_at, :utc_datetime # Already exists, do not add again
    end

    # Create indexes for better query performance
    # create index(:placed_bets, [:status]) # Already exists, do not create again
    create index(:placed_bets, [:result])
    create index(:placed_bets, [:user_id, :status])
  end
end
