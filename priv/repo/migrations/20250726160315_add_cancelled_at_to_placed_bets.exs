defmodule BetZone.Repo.Migrations.AddCancelledAtToPlacedBets do
  use Ecto.Migration

  def change do
    alter table(:placed_bets) do
      add :cancelled_at, :utc_datetime
    end
  end
end
