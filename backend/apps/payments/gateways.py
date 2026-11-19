"""Payment gateway adapters.

The rest of the system only talks to `PaymentGateway`. Plugging in the chosen
Tanzanian aggregator (see docs/PAYMENTS.md) means writing one subclass and
setting PAYMENT_GATEWAY; nothing in subscriptions or the API changes.
"""

import hashlib
import hmac
import json
from dataclasses import dataclass, field

from django.conf import settings


@dataclass
class GatewayResult:
    status: str  # "pending", "success" or "failed"
    gateway_reference: str = ""
    amount: object = None
    message: str = ""
    raw: dict = field(default_factory=dict)


class CallbackRejected(Exception):
    pass


class PaymentGateway:
    name = "base"

    def initiate(self, transaction) -> GatewayResult:
        """Send a USSD push / STK prompt to the customer's phone."""
        raise NotImplementedError

    def check_status(self, transaction) -> GatewayResult:
        """Ask the gateway directly what happened. Never trust the phone app's word."""
        raise NotImplementedError

    def parse_callback(self, request) -> tuple[str, GatewayResult]:
        """Verify the callback is genuinely from the gateway; return (our reference, result)."""
        raise NotImplementedError


class SandboxGateway(PaymentGateway):
    """Simulated gateway for development and tests. Refused in production by settings.

    Phone numbers ending in 0000 fail; every other number succeeds when checked.
    """

    name = "sandbox"

    def initiate(self, transaction):
        return GatewayResult(
            status="pending",
            gateway_reference=f"SBX-{transaction.reference}",
            message="Sandbox: prompt sent.",
        )

    def check_status(self, transaction):
        if transaction.phone.endswith("0000"):
            return GatewayResult(status="failed", gateway_reference=transaction.gateway_reference,
                                 message="Sandbox: customer declined.")
        return GatewayResult(status="success", gateway_reference=transaction.gateway_reference,
                             amount=transaction.amount, message="Sandbox: paid.")

    def parse_callback(self, request):
        secret = settings.PAYMENT_CALLBACK_SECRET
        signature = request.headers.get("X-Signature", "")
        expected = hmac.new(secret.encode(), request.body, hashlib.sha256).hexdigest() if secret else ""
        if not secret or not hmac.compare_digest(signature, expected):
            raise CallbackRejected("Bad signature.")
        data = json.loads(request.body)
        return data["reference"], GatewayResult(
            status=data["status"],
            gateway_reference=data.get("gateway_reference", ""),
            amount=data.get("amount"),
            message=data.get("message", ""),
            raw=data,
        )


GATEWAYS = {SandboxGateway.name: SandboxGateway}


def get_gateway(name=None) -> PaymentGateway:
    name = name or settings.PAYMENT_GATEWAY
    try:
        return GATEWAYS[name]()
    except KeyError as exc:
        raise RuntimeError(f"Unknown payment gateway '{name}'.") from exc
