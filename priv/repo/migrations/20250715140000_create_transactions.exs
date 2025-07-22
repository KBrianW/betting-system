defmodule BetZone.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :type, :string, null: false  # deposit, withdrawal, bet_place, bet_win, bet_loss
      add :status, :string, null: false, default: "pending"  # pending, completed, failed
      add :reference, :string  # for payment reference
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:type])
    create index(:transactions, [:status])
  end
end
