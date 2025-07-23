defmodule BetZone.Repo.Migrations.CreateDraftAndHistoryTables do
  use Ecto.Migration

  def change do
    create table(:draft_bets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :game_desc, :string
      add :type, :string
      add :odds, :float
      add :stake, :integer
      add :status, :string, default: "pending"

      timestamps()
    end

    create index(:draft_bets, [:user_id])

    create table(:user_histories) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :info, :string
      add :type, :string
      add :ref_id, :integer

      timestamps()
    end

    create index(:user_histories, [:user_id])
  end
end
