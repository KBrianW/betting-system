defmodule BettingSystemWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use BettingSystemWeb, :controller` and
  `use BettingSystemWeb, :live_view`.
  """
  use BettingSystemWeb, :html

  embed_templates "layouts/*"
end
