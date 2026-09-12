# PHASE 08 — ATOMIC SALE CHECKOUT & SPLIT PAYMENTS

## 8-WAY ATOMIC TRANSACTION
A checkout atomically creates: `sale`, `sale_items`, `inventory_movements` (OUT), `payment_allocations`, `wallet_transactions` (IN), `customer_ledger`, `audit_event`, `sync_event`.
Split payments must strictly sum to invoice total.
