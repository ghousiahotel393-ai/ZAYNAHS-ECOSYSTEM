# AGENTS — UNIVERSAL POS ENGINE & INVENTORY LEDGER

# 23. UNIVERSAL POS RULE

There is ONE POS engine.

Do NOT create separate engines for:

    clothing
    electronics
    pharmacy
    grocery
    restaurant
    cosmetics

Business templates may configure:

    visibility
    labels
    required fields
    workflows

Core transaction logic remains shared.

---

# 24. POS SOURCE OF TRUTH

Inventory is based on immutable movement events.

Wallets are based on immutable wallet transactions.

Sales are authoritative records.

Returns are separate transactions.

Replacements are linked transactions.

Do not use UI counters as financial truth.

---

# 25. INVENTORY RULE

Inventory must be derived from movement ledger.

Formula:

    Opening
    + Stock IN
    + Purchase
    + Returns
    + Adjustment IN
    + Replacement IN
    - Sales
    - Stock OUT
    - Damage
    - Expiry
    - Loss
    - Adjustment OUT
    - Replacement OUT
    = Current Stock

---

# 26. IMMUTABLE INVENTORY

Never edit an old inventory movement to fix a mistake.

Create:

    correcting movement
    adjustment
    reversal
    void
    replacement event

as appropriate.

---
