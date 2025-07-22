defmodule BetZone.Repo.Migrations.ChangeAmountToDecimal do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      modify :amount, :decimal, precision: 10, scale: 2
    end
  end
end
