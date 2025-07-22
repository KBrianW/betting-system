defmodule BetZone.Repo.Migrations.CreatePlacedBets do
  use Ecto.Migration

  def change do
    create table(:placed_bets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :total_odds, :decimal, precision: 10, scale: 2, null: false
      add :stake_amount, :decimal, precision: 10, scale: 2, null: false
      add :potential_win, :decimal, precision: 10, scale: 2, null: false
      add :status, :string, null: false, default: "pending"  # pending, won, lost, cancelled
      add :settled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create table(:bet_selections) do
      add :placed_bet_id, references(:placed_bets, on_delete: :delete_all), null: false
      add :game_id, references(:games, on_delete: :restrict), null: false
      add :selection_type, :string, null: false  # win, draw, loss
      add :odds, :decimal, precision: 10, scale: 2, null: false
      add :result, :string  # won, lost, pending, cancelled

      timestamps(type: :utc_datetime)
    end

    create index(:placed_bets, [:user_id])
    create index(:placed_bets, [:status])
    create index(:bet_selections, [:placed_bet_id])
    create index(:bet_selections, [:game_id])
  end
end
