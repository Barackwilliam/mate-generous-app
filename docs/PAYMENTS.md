# Payments

## The flow

1. The app calls `POST /api/payments/start/` with the plan (or item/series), phone number and network.
2. The backend creates a `Transaction` (reference `MG…`), and the gateway sends a USSD/STK prompt to the phone.
3. The customer enters their PIN.
4. The gateway calls `POST /api/payments/callback/<gateway>/`, and the app polls `GET /api/payments/<reference>/`. **The backend checks with the gateway itself.** It never trusts the phone's word that the payment went through.
5. On a verified payment of the **right amount**, the backend activates the subscription or purchase, records the transaction, and calculates the expiry date.
6. The app shows the confirmation from the transaction record (reference, amount, item, time).

Steps 4–5 are idempotent. A callback, several polls and an admin confirmation can all arrive for the same payment, and the user still gets exactly one subscription.

**Manual activation** for exceptional cases is in the admin under Transactions, with actions to confirm or mark failed. Every use is written to the audit log with the staff member and time.

## Gateway recommendation

Use **one aggregator** that covers M-Pesa, Airtel Money and Mixx by Yas behind a single API, instead of three separate operator integrations. Tanzanian options to compare:

| Gateway | Why consider it |
| --- | --- |
| **Selcom** | Long-established in Tanzania, wide mobile money and card coverage |
| **AzamPay** | Developer-friendly REST API and sandbox, covers the main mobile networks |
| **ClickPesa** | Simple onboarding, mobile money plus cards |

**Recommendation:** shortlist AzamPay and Selcom, ask both for current fees, settlement time and onboarding requirements (business registration, TIN), and choose the cheapest one that offers a sandbox. Fees and terms change, so they must be confirmed directly with each provider before deciding.

Adding the chosen gateway means writing one class in `backend/apps/payments/gateways.py` (`initiate`, `check_status`, `parse_callback`) and setting `PAYMENT_GATEWAY`. Nothing else changes.

## ⚠️ Google Play policy: decide before launch

Google Play's payments policy generally requires apps distributed on Play to use **Google Play Billing** for in-app sales of digital content and subscriptions. Devotionals, audio, books and courses all count as digital content. Selling them inside the app through mobile money alone risks the app being rejected or removed.

Options to discuss with the client:

1. **Pay on the web:** the subscription is bought on a web page using mobile money, and the app only signs in and reads. This pattern is common, but Play's rules on linking to outside payment from inside the app are strict, so it must be checked against the current policy.
2. **Google Play Billing** in the app, with mobile money on the web. Google takes a commission, but it is the most clearly compliant route.
3. **Alternative billing programmes:** Google runs these in some countries. Whether Tanzania is covered needs to be checked at the time.

The backend supports all three. Entitlements do not care where the money came from, so a Play Billing adapter can be added later as another source. **This needs the client's decision before the payment screen in the app is finalised.**
