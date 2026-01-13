defmodule OhioElixir.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email with Ohio Elixir branding.
  """

  use AshAuthentication.Sender
  use OhioElixirWeb, :verified_routes

  import Swoosh.Email
  alias OhioElixir.Mailer

  @impl true
  def send(user_or_email, token, _) do
    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    url = url(~p"/auth/user/magic_link?token=#{token}")

    new()
    |> from({"Ohio Elixir", "noreply@ohioelixir.com"})
    |> to(to_string(email))
    |> subject("Sign in to Ohio Elixir")
    |> html_body(html_body(url))
    |> text_body(text_body(url))
    |> Mailer.deliver!()
  end

  defp html_body(url) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Sign in to Ohio Elixir</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f9fafb;">
      <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: #f9fafb;">
        <tr>
          <td style="padding: 40px 20px;">
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width: 500px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; border: 1px solid #e5e7eb;">
              <!-- Header -->
              <tr>
                <td style="padding: 32px 32px 24px 32px; border-bottom: 1px solid #e5e7eb;">
                  <h1 style="margin: 0; font-size: 24px; font-weight: 700; color: #1f2937;">
                    Ohio Elixir
                  </h1>
                </td>
              </tr>

              <!-- Content -->
              <tr>
                <td style="padding: 32px;">
                  <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 24px; color: #374151;">
                    Hello,
                  </p>
                  <p style="margin: 0 0 24px 0; font-size: 16px; line-height: 24px; color: #374151;">
                    Click the button below to sign in to your Ohio Elixir account. This link will expire in 10 minutes.
                  </p>

                  <!-- CTA Button -->
                  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                    <tr>
                      <td style="padding: 0 0 24px 0;">
                        <a href="#{url}" target="_blank" style="display: inline-block; padding: 14px 28px; background-color: #6d28d9; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: 600; border-radius: 6px;">
                          Sign In to Ohio Elixir
                        </a>
                      </td>
                    </tr>
                  </table>

                  <p style="margin: 0 0 8px 0; font-size: 14px; line-height: 20px; color: #6b7280;">
                    Or copy and paste this link into your browser:
                  </p>
                  <p style="margin: 0; font-size: 14px; line-height: 20px; word-break: break-all;">
                    <a href="#{url}" target="_blank" style="color: #6d28d9;">#{url}</a>
                  </p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="padding: 24px 32px; background-color: #f9fafb; border-top: 1px solid #e5e7eb; border-radius: 0 0 8px 8px;">
                  <p style="margin: 0 0 8px 0; font-size: 14px; line-height: 20px; color: #6b7280;">
                    If you didn't request this email, you can safely ignore it.
                  </p>
                  <p style="margin: 0; font-size: 14px; line-height: 20px; color: #9ca3af;">
                    Ohio Elixir Community
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end

  defp text_body(url) do
    """
    Ohio Elixir - Sign In

    Hello,

    Click the link below to sign in to your Ohio Elixir account.
    This link will expire in 10 minutes.

    #{url}

    If you didn't request this email, you can safely ignore it.

    ---
    Ohio Elixir Community
    """
  end
end
