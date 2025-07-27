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

# Only clear and seed teams if they don't exist
if Repo.aggregate(Team, :count, :id) == 0 do
  team_names = [
    "Arsenal", "Chelsea", "Liverpool", "Manchester United", "Manchester City",
    "Tottenham", "Everton", "Leicester City", "West Ham", "Newcastle United",
    "Aston Villa", "Wolves", "Crystal Palace", "Southampton", "Leeds United",
    "Brighton", "Burnley", "Norwich City", "Watford", "Brentford"
  ]

  for name <- team_names do
    Repo.insert!(%Team{name: name})
  end
  
  IO.puts("✅ Teams seeded successfully!")
else
  IO.puts("ℹ️  Teams already exist, skipping team seeding.")
end

# Seed sample users for each role (only if they don't exist)
users_to_create = [
  %{
    email: "user@example.com",
    password: "password123456",
    first_name: "Regular",
    last_name: "User",
    msisdn: "+10000000001",
    role: :frontend,
    status: :active
  },
  %{
    email: "admin@example.com",
    password: "password123456",
    first_name: "Admin",
    last_name: "User",
    msisdn: "+10000000002",
    role: :admin,
    status: :active
  },
  %{
    email: "super@example.com",
    password: "password123456",
    first_name: "Super",
    last_name: "Admin",
    msisdn: "+10000000003",
    role: :super_user,
    status: :active
  }
]

for user_attrs <- users_to_create do
  case Accounts.get_user_by_email(user_attrs.email) do
    nil ->
      case Accounts.register_user(user_attrs) do
        {:ok, user} ->
          IO.puts("✅ Created #{user_attrs.role} user: #{user_attrs.email}")
        {:error, changeset} ->
          IO.puts("❌ Failed to create user #{user_attrs.email}: #{inspect(changeset.errors)}")
      end
    _existing_user ->
      IO.puts("ℹ️  User #{user_attrs.email} already exists, skipping.")
  end
end

IO.puts("\n🎉 Seeding completed!")
IO.puts("\n📋 Available login credentials:")
IO.puts("👤 Regular User: user@example.com / password123456")
IO.puts("🛡️  Admin User: admin@example.com / password123456")
IO.puts("⚡ Super User: super@example.com / password123456")
IO.puts("\n🔗 Access URLs:")
IO.puts("📱 User Dashboard: http://localhost:4000/")
IO.puts("🛡️  Admin Panel: http://localhost:4000/admin_panel")
IO.puts("⚡ Super Panel: http://localhost:4000/super_panel")