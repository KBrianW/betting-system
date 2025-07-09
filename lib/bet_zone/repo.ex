defmodule BetZone.Repo do
  use Ecto.Repo,
    otp_app: :bet_zone,
    adapter: Ecto.Adapters.Postgres
end
