"""
Email and Token Management Utilities
Gère la génération de tokens et l'envoi d'emails
"""

import secrets
from datetime import datetime, timedelta
from typing import Optional


# ============================================
# GÉNÉRATION DE TOKENS SÉCURISÉS
# ============================================

def generate_verification_token() -> str:
    """
    Génère un token de vérification sécurisé (32 caractères aléatoires)
    
    Returns:
        Token hexadécimal unique
    """
    return secrets.token_urlsafe(32)


def generate_reset_password_token() -> str:
    """
    Génère un token de réinitialisation de mot de passe (32 caractères)
    
    Returns:
        Token hexadécimal unique
    """
    return secrets.token_urlsafe(32)


def get_token_expiry(hours: int = 24) -> datetime:
    """
    Calcule la date d'expiration d'un token
    
    Args:
        hours: Nombre d'heures avant expiration (défaut: 24h)
        
    Returns:
        Datetime d'expiration
    """
    return datetime.utcnow() + timedelta(hours=hours)


def is_token_expired(expires_at: Optional[datetime]) -> bool:
    """
    Vérifie si un token a expiré
    
    Args:
        expires_at: Date d'expiration du token
        
    Returns:
        True si expiré, False sinon
    """
    if expires_at is None:
        return True
    return datetime.utcnow() > expires_at


# ============================================
# SIMULATION D'ENVOI D'EMAILS
# ============================================

def send_verification_email(email: str, full_name: str, token: str) -> bool:
    """
    Envoie un email de vérification (SIMULATION pour le hackathon)
    
    En production, utilisez un service comme SendGrid, Mailgun, ou AWS SES
    
    Args:
        email: Email du destinataire
        full_name: Nom complet de l'utilisateur
        token: Token de vérification
        
    Returns:
        True si l'email a été "envoyé"
    """
    
    # URL de vérification (à adapter selon votre frontend)
    verification_url = f"http://127.0.0.1:8000/api/v1/verify-email?token={token}"
    # Ou pour le web: f"https://morchidhub.ma/verify-email?token={token}"
    
    # ============================================
    # SIMULATION - Affichage dans la console
    # ============================================
    print("\n" + "="*70)
    print("EMAIL DE VÉRIFICATION (SIMULATION)")
    print("="*70)
    print(f"À: {email}")
    print(f"Sujet: Bienvenue sur Morchid Hub - Vérifiez votre compte")
    print("-"*70)
    print(f"Bonjour {full_name},")
    print()
    print("Merci de vous être inscrit sur Morchid Hub !")
    print("Pour activer votre compte, veuillez cliquer sur le lien ci-dessous :")
    print()
    print(f"URL: {verification_url}")
    print()
    print("Ce lien est valide pendant 24 heures.")
    print()
    print("Si vous n'avez pas créé ce compte, ignorez cet email.")
    print("-"*70)
    print(f"Token (pour tests): {token}")
    print("="*70 + "\n")
    
    # TODO en production: Remplacer par un vrai service d'envoi d'email
    # Exemple avec SendGrid:
    # from sendgrid import SendGridAPIClient
    # from sendgrid.helpers.mail import Mail
    # 
    # message = Mail(
    #     from_email='noreply@morchidhub.ma',
    #     to_emails=email,
    #     subject='Vérifiez votre compte Morchid Hub',
    #     html_content=f'<p>Cliquez ici: <a href="{verification_url}">Vérifier</a></p>'
    # )
    # sg = SendGridAPIClient(os.environ.get('SENDGRID_API_KEY'))
    # response = sg.send(message)
    
    return True


def send_password_reset_email(email: str, full_name: str, token: str) -> bool:
    """
    Envoie un email de réinitialisation de mot de passe (SIMULATION)
    
    Args:
        email: Email du destinataire
        full_name: Nom complet de l'utilisateur
        token: Token de réinitialisation
        
    Returns:
        True si l'email a été "envoyé"
    """
    
    # URL de réinitialisation
    reset_url = f"http://127.0.0.1:8000/api/v1/reset-password-page?token={token}"
    # Ou pour le web: f"https://morchidhub.ma/reset-password?token={token}"
    
    # ============================================
    # SIMULATION - Affichage dans la console
    # ============================================
    print("\n" + "="*70)
    print("EMAIL DE RÉINITIALISATION (SIMULATION)")
    print("="*70)
    print(f"À: {email}")
    print(f"Sujet: Réinitialisation de votre mot de passe Morchid Hub")
    print("-"*70)
    print(f"Bonjour {full_name},")
    print()
    print("Vous avez demandé à réinitialiser votre mot de passe.")
    print("Pour créer un nouveau mot de passe, cliquez sur le lien ci-dessous :")
    print()
    print(f"URL: {reset_url}")
    print()
    print("Ce lien est valide pendant 24 heures.")
    print()
    print("Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.")
    print("Votre mot de passe actuel reste inchangé.")
    print("-"*70)
    print(f"Token (pour tests): {token}")
    print("="*70 + "\n")

    return True


def send_password_changed_confirmation(email: str, full_name: str) -> bool:
    """
    Envoie un email de confirmation après changement de mot de passe
    
    Args:
        email: Email du destinataire
        full_name: Nom complet de l'utilisateur
        
    Returns:
        True si l'email a été "envoyé"
    """
    
    print("\n" + "="*70)
    print("CONFIRMATION DE CHANGEMENT (SIMULATION)")
    print("="*70)
    print(f"À: {email}")
    print(f"Sujet: Votre mot de passe a été modifié")
    print("-"*70)
    print(f"Bonjour {full_name},")
    print()
    print("Votre mot de passe Morchid Hub a été modifié avec succès.")
    print()
    print("Si vous n'êtes pas à l'origine de cette modification,")
    print("contactez immédiatement notre support à support@morchidhub.ma")
    print("-"*70)
    print("="*70 + "\n")
    
    return True
