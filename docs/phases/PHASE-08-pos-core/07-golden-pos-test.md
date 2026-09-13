# PHASE 08 — GOLDEN POS TEST (RULE 100)

## TEST SCENARIO
Item price 100, initial stock 100.
Sales: 4 cash, 5 online, 10 bank.
Discounted split sale: 5 items, gross 500, discount 50, net 450 (split 225 cash / 225 bank).
Return: 3 items returned, refund 270 (split 135 cash / 135 bank).
Verify: stock = 79, all wallet totals match ledger exactly.

- [x] Strictly ONE Universal POS Engine across clothing, electronics, pharmacy, and dining.
- [x] Business templates configure only labels and attributes (`attributes_json`), never modifying core logic.
- [x] Append-only immutable inventory ledger deriving authoritative stock balance.
- [x] Negative stock policy enforcement (`BLOCK` by default, `WARN`, `ALLOW`).
- [x] Multi-wallet split payment checkout with 8-way atomic SQLite transaction.
- [x] Authoritative returns and refunds with proportional discount preservation.
- [x] Master Schema Version 4.0: `sale_payments`, `returns`, `return_items`, `return_payments`, and `attributes_json`.
- [x] Golden Test 100: Reconciled stock (79), Cash (490), Online (500), Bank (1090), Total Wallets (2080).

## VERIFICATION SIGN-OFF
- **Status**: ✅ COMPLETED & VERIFIED
- **Automated Verification Script**: `scripts/verify_phase_08.sh` (100% Green)
- **Unit Tests**: `tests/unit/pos_test.dart` (4/4 passing, including Golden Test 100)
- **Database Tests**: `tests/unit/database_test.dart` (8/8 passing, including v1->v4 migration)
- **Master Test Battery**: `tests/run_all.dart` (54/54 passing across Phases 01-08)
