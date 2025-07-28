
alias BetZone.Repo
alias BetZone.Accounts.User

# Update user roles
users_to_update = [
  {"user@example.com", :frontend},
  {"admin@example.com", :admin},
  {"super@example.com", :super_user}
]

for {email, role} <- users_to_update do
  case Repo.get_by(User, email: email) do
    nil ->
      IO.puts("❌ User #{email} not found")
    user ->
      changeset = Ecto.Changeset.change(user, role: role)
      case Repo.update(changeset) do
        {:ok, updated_user} ->
          IO.puts("✅ Updated #{email} to role: #{role}")
        {:error, changeset} ->
          IO.puts("❌ Failed to update #{email}: #{inspect(changeset.errors)}")
      end
  end
end

IO.puts("\n User roles updated!")
IO.puts("\n Login credentials:")
IO.puts(" Frontend User: user@example.com / password123456 → /dashboard")
IO.puts("  Admin User: admin@example.com / password123456 → /super_panel")
IO.puts(" Super User: super@example.com / password123456 → /super_panel")
