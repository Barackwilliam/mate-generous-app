"""Payment flow: initiate → verify → activate entitlement → record.

`apply_result` is the only function that moves a transaction to success, and
it is idempotent: the gateway callback, a status poll from the app, and an
admin confirmation can all arrive for the same payment and the user still gets
exactly one subscription or purchase.
"""

import logging
from decimal import Decimal

from django.db import transaction as db_transaction
from django.utils import timezone

from apps.audit.models import AuditLog, record
from apps.subscriptions.models import Purchase, Subscription, create_subscription

from .gateways import GatewayResult, get_gateway
from .models import Transaction

log = logging.getLogger(__name__)


class PaymentError(Exception):
    pass


def start_payment(user, *, phone, network, plan=None, content=None, series=None):
    if sum(x is not None for x in (plan, content, series)) != 1:
        raise PaymentError("Choose exactly one thing to pay for.")
    if plan is not None:
        if not plan.is_active or plan.price <= 0:
            raise PaymentError("Mpango huu haupatikani kwa sasa.")
        kind, amount = Transaction.Kind.SUBSCRIPTION, plan.price
    else:
        product = content or series
        if product.price is None or product.price <= 0:
            raise PaymentError("Bidhaa hii haiuzwi peke yake.")
        if Purchase.objects.filter(user=user, content=content, series=series, revoked_at__isnull=True).exists():
            raise PaymentError("Tayari unamiliki bidhaa hii.")
        kind, amount = Transaction.Kind.PRODUCT, product.price

    gateway = get_gateway()
    txn = Transaction.objects.create(
        user=user, kind=kind, plan=plan, content=content, series=series,
        amount=amount, phone=phone, network=network, gateway=gateway.name,
    )
    try:
        result = gateway.initiate(txn)
    except Exception:  # network trouble talking to the gateway
        log.exception("Gateway initiate failed for %s", txn.reference)
        result = GatewayResult(status="failed", message="Imeshindikana kuwasiliana na mtoa huduma wa malipo.")
    txn.log("initiate", result.raw or {"message": result.message})
    txn.gateway_reference = result.gateway_reference
    txn.save(update_fields=["gateway_reference", "gateway_payload", "updated_at"])
    if result.status == "failed":
        apply_result(txn.pk, result, source="initiate")
        txn.refresh_from_db()
    return txn


def refresh_status(txn):
    """Ask the gateway for the truth about a pending transaction."""
    if txn.status != Transaction.Status.PENDING:
        return txn
    result = get_gateway(txn.gateway).check_status(txn)
    if result.status != "pending":
        apply_result(txn.pk, result, source="status_check")
        txn.refresh_from_db()
    return txn


def apply_result(txn_pk, result: GatewayResult, *, source, actor=None, reason=""):
    with db_transaction.atomic():
        txn = Transaction.objects.select_for_update().get(pk=txn_pk)
        txn.log(source, result.raw or {"status": result.status, "message": result.message})

        if txn.status != Transaction.Status.PENDING:
            txn.save(update_fields=["gateway_payload", "updated_at"])
            return txn

        if result.status == "success" and result.amount is not None and Decimal(str(result.amount)) != txn.amount:
            result = GatewayResult(status="failed", message=f"Amount mismatch: paid {result.amount}, expected {txn.amount}.")
            log.warning("Amount mismatch on %s", txn.reference)

        if result.status == "success":
            txn.status = Transaction.Status.SUCCESS
            txn.completed_at = timezone.now()
            if result.gateway_reference:
                txn.gateway_reference = result.gateway_reference
            txn.save()
            _fulfil(txn, manual=actor is not None, note=reason)
        elif result.status == "failed":
            txn.status = Transaction.Status.FAILED
            txn.failure_reason = result.message[:255]
            txn.completed_at = timezone.now()
            txn.save()
        else:
            txn.save(update_fields=["gateway_payload", "updated_at"])
            return txn

        if actor is not None:
            record(
                AuditLog.Action.TRANSACTION_MANUAL_CONFIRM if result.status == "success"
                else AuditLog.Action.TRANSACTION_MANUAL_FAIL,
                actor=actor, target_user=txn.user, obj=txn, reason=reason,
                reference=txn.reference, amount=str(txn.amount),
            )
    return txn


def _fulfil(txn, *, manual, note):
    if txn.kind == Transaction.Kind.SUBSCRIPTION:
        create_subscription(
            txn.user, txn.plan, transaction=txn, note=note,
            source=Subscription.Source.MANUAL if manual else Subscription.Source.PAYMENT,
        )
    else:
        Purchase.objects.create(
            user=txn.user, content=txn.content, series=txn.series, amount=txn.amount,
            transaction=txn, note=note,
            source=Purchase.Source.MANUAL if manual else Purchase.Source.PAYMENT,
        )
