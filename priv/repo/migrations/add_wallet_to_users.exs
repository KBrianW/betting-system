defmodule BetZone.Repo.Migrations.AddWalletToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :wallet, :integer, default: 0, null: false
    end
  end
end
