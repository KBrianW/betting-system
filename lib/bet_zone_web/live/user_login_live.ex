defmodule BetZoneWeb.UserLoginLive do
  use BetZoneWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center text-2xl font-bold mb-4">Log in to your account</.header>
      <%= if @flash[:error] do %>
        <div class="mb-4 text-red-600"><%= @flash[:error] %></div>
      <% end %>
      <form method="post" action="/users/log_in" id="login_form">
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <div class="mb-4">
          <label for="user_email" class="block text-sm font-medium">Email</label>
          <input type="email" name="user[email]" id="user_email" required class="w-full border rounded px-3 py-2" value={@email || ""} />
        </div>
        <div class="mb-4">
          <label for="user_password" class="block text-sm font-medium">Password</label>
          <input type="password" name="user[password]" id="user_password" required class="w-full border rounded px-3 py-2" />
        </div>
        <div class="mb-4 flex items-center">
          <input type="checkbox" name="user[remember_me]" id="user_remember_me" class="mr-2" />
          <label for="user_remember_me" class="text-sm">Keep me logged in</label>
        </div>
        <div class="mb-4 flex justify-between items-center">
          <a href="/users/reset_password" class="text-sm text-blue-600 hover:underline">Forgot your password?</a>
          <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded">Log in →</button>
        </div>
        <div class="text-center text-sm">
          Don't have an account?
          <a href="/users/register" class="text-blue-600 hover:underline">Sign up</a>
          for an account now.
        </div>
      </form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, email: "")}
  end
end
