defmodule RealmsWeb.UserSessionHTML do
  use RealmsWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:realms, Realms.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
