"""Service de notification (emails transactionnels).

Encapsule `email_utils` derrière une interface stable. Aujourd'hui l'envoi est
une simulation console ; le jour où un vrai SMTP/SendGrid est branché, seul ce
service change — les services métier appellent toujours les mêmes méthodes.
"""

from .. import email_utils


class NotificationService:

    def send_verification_email(self, email: str, full_name: str, token: str) -> None:
        email_utils.send_verification_email(email=email, full_name=full_name, token=token)

    def send_password_reset_email(self, email: str, full_name: str, token: str) -> None:
        email_utils.send_password_reset_email(email=email, full_name=full_name, token=token)

    def send_password_changed_confirmation(self, email: str, full_name: str) -> None:
        email_utils.send_password_changed_confirmation(email=email, full_name=full_name)
