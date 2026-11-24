import hashlib
import hmac
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone

from .models import PasswordResetCode, User, normalize_phone

log = logging.getLogger(__name__)


def _hash(code):
    return hmac.new(settings.SECRET_KEY.encode(), code.encode(), hashlib.sha256).hexdigest()


def find_user(identifier):
    identifier = (identifier or "").strip()
    if "@" in identifier:
        return User.objects.filter(email=identifier.lower(), is_active=True).first()
    phone = normalize_phone(identifier)
    return User.objects.filter(phone=phone, is_active=True).first() if phone else None


def send_code(identifier):
    """Email a fresh code. Says nothing about whether the account exists."""
    user = find_user(identifier)
    if user is None:
        return
    code = f"{secrets.randbelow(10**6):06d}"
    PasswordResetCode.objects.filter(user=user, used_at__isnull=True).update(used_at=timezone.now())
    PasswordResetCode.objects.create(
        user=user, code_hash=_hash(code),
        expires_at=timezone.now() + timedelta(minutes=PasswordResetCode.TTL_MINUTES),
    )
    body = (
        f"Habari {user.full_name},\n\n"
        f"Namba yako ya kubadilisha nenosiri la Mate Generous ni: {code}\n"
        f"Inafanya kazi kwa dakika {PasswordResetCode.TTL_MINUTES}. Kama hukuomba, puuza ujumbe huu.\n\n"
        f"---\n\n"
        f"Your Mate Generous password reset code is: {code}\n"
        f"It works for {PasswordResetCode.TTL_MINUTES} minutes. If you did not ask for it, ignore this email.\n"
    )
    try:
        send_mail("Mate Generous: namba ya kubadilisha nenosiri / password reset code", body,
                  settings.DEFAULT_FROM_EMAIL, [user.email])
    except Exception:
        log.exception("Could not send the password reset email")


class ResetError(Exception):
    pass


def reset_password(identifier, code, new_password):
    """Raise ResetError, or return the user with the new password set.

    The error is raised after the transaction commits, so a wrong guess is
    always counted (raising inside it would roll the count back).
    """
    error = None
    with transaction.atomic():
        user = find_user(identifier)
        entry = (
            PasswordResetCode.objects.select_for_update().filter(user=user, used_at__isnull=True).first()
            if user else None
        )
        if entry is None or not entry.usable:
            error = "Namba si sahihi au imeisha muda. Omba nyingine."
        elif not hmac.compare_digest(entry.code_hash, _hash((code or "").strip())):
            entry.attempts += 1
            entry.save(update_fields=["attempts"])
            error = "Namba si sahihi."
        else:
            user.set_password(new_password)
            user.save(update_fields=["password"])
            entry.used_at = timezone.now()
            entry.save(update_fields=["used_at"])
    if error:
        raise ResetError(error)
    return user
