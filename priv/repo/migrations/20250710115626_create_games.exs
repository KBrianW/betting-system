defmodule BetZone.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :scheduled_time, :utc_datetime
      add :odds_win, :float
      add :odds_draw, :float
      add :odds_loss, :float
      add :status, :string
      add :score_a, :integer
      add :score_b, :integer
      add :week, :integer
      add :cycle, :integer
      add :team_a_id, references(:teams, on_delete: :nothing)
      add :team_b_id, references(:teams, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:team_a_id])
    create index(:games, [:team_b_id])
  end
end
