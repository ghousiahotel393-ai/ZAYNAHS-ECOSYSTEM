# PHASE 09 — PHYSICAL STOCK AUDITS

## STOCK TAKE WORKFLOW
Snapshot expected stock → Physical scan count → Variance calculation → Approval → Adjustment event posted to ledger.

- [x] Multi-tier tax engine: inclusive/exclusive taxes (GST 18%, VAT 5%, Zero-rated).
- [x] Discount limits: Cashier threshold capped at 10% with verified Manager/Admin PIN override.
- [x] Barcode engine: Modulo-10 check digit calculation and verification for EAN-13 and UPC-A, Code 128, and QR payload.
- [x] Thermal ESC/POS printing: 58mm & 80mm receipt generation, table alignment, paper cut, and cash drawer kick pulse.
- [x] Procurement service: Purchase orders, restock events (Stock IN), and supplier payables ledger (`Purchases - Payments`).
- [x] Physical stock take audits (Rule 51): Expected snapshot, physical scan, discrepancy variance, manager approval, compensating adjustment posting.
- [x] Master Schema Version 5.0: `suppliers`, `purchase_orders`, `purchase_order_items`, `stock_counts`, and `stock_count_items`.

## VERIFICATION SIGN-OFF
- **Status**: ✅ COMPLETED & VERIFIED
- **Automated Verification Script**: `scripts/verify_phase_09.sh` (100% Green)
- **Unit Tests**: `tests/unit/advanced_pos_test.dart` (6/6 passing)
- **Database Tests**: `tests/unit/database_test.dart` (8/8 passing, including v1->v5 migration)
- **Master Test Battery**: `tests/run_all.dart` (60/60 passing across Phases 01-09)
