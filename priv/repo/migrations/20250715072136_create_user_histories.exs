defmodule BetZone.Repo.Migrations.CreateUserHistories do
  use Ecto.Migration

  def change do
    create table(:user_histories) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :from, :string
      add :info, :string
      add :event_type, :string
      add :related_id, :integer
      add :amount, :float
      timestamps(type: :utc_datetime)
    end

    create index(:user_histories, [:user_id])
    create index(:user_histories, [:related_id])
  end
end
