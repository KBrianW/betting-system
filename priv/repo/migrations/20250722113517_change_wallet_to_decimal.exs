defmodule BetZone.Repo.Migrations.ChangeWalletToDecimal do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :wallet, :decimal, precision: 10, scale: 2, default: 0.0, null: false
    end
  end
end
