defmodule BetZoneWeb.UserLoginLive do
  use BetZoneWeb, :live_view


  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Log in to your account
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Register
          </.link>
          for a new account now.
        </:subtitle>
      </.header>

      <.flash_group flash={@flash} />

      <.simple_form
        for={@form}
        id="login_form"
        action={~p"/users/log_in"}
        method="post"
        autocomplete="off"
        phx-debounce="300"
      >
        <.error :if={@form.errors != []}>
          Invalid email or password.
        </.error>

        <.input field={@form[:email]} type="email" label="Email" required autocomplete="off" />
        <.input field={@form[:password]} type="password" label="Password" required autocomplete="new-password" />

        <:actions>
          <div class="flex flex-col space-y-4 w-full">
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" class="w-auto" />
            <.button phx-disable-with="Logging in..." class="w-full">Log in →</.button>
            <.link navigate={~p"/users/reset_password"} class="text-sm text-brand hover:underline text-center">
              Forgot your password?
            </.link>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    form =
      %{}
      |> to_form(as: "user")

    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end
end
