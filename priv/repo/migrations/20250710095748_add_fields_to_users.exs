defmodule BetZone.Repo.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
     add :first_name, :string
     add :last_name, :string
     add :msisdn, :string
     add :role, :string, default: "frontend"
     add :status, :string, default: "active"
    end
  end
end
