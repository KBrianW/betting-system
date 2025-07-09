# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BetZone.Repo.insert!(%BetZone.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias BetZone.Teams.Team
alias BetZone.Repo
alias BetZone.Games.Game
alias BetZone.Accounts

# Clear games and teams tables before seeding
Repo.delete_all(Game)
Repo.delete_all(Team)

team_names = [
  "Arsenal", "Chelsea", "Liverpool", "Manchester United", "Manchester City",
  "Tottenham", "Everton", "Leicester City", "West Ham", "Newcastle United",
  "Aston Villa", "Wolves", "Crystal Palace", "Southampton", "Leeds United",
  "Brighton", "Burnley", "Norwich City", "Watford", "Brentford"
]

for name <- team_names do
  Repo.insert!(%Team{name: name})
end

# Seed sample users for each role
Accounts.register_user(%{
  email: "user@example.com",
  password: "password123456",
  first_name: "Regular",
  last_name: "User",
  msisdn: "+10000000001",
  role: "frontend",
  status: "active"
})

Accounts.register_user(%{
  email: "admin@example.com",
  password: "password123456",
  first_name: "Admin",
  last_name: "User",
  msisdn: "+10000000002",
  role: "admin",
  status: "active"
})

Accounts.register_user(%{
  email: "super@example.com",
  password: "password123456",
  first_name: "Super",
  last_name: "User",
  msisdn: "+10000000003",
  role: "super_user",
  status: "active"
})
