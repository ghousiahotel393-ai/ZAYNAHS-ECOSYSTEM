# GEMINI — SALES, RETURNS & REPLACEMENTS TRANSACTIONS

# 46. SALE TRANSACTION

Sale must atomically create:

    sale
    sale_items
    inventory OUT
    payment allocations
    wallet transactions
    customer ledger
    audit
    sync event

---

# 47. RETURN TRANSACTION

Return must create:

    return
    return items
    inventory IN
    refund
    wallet OUT
    customer ledger
    audit
    sync event

---

# 48. REPLACEMENT

Replacement must track:

    original sale
    returned item
    replacement item
    inventory IN
    inventory OUT
    difference
    refund/additional payment
    audit
    sync

---

# 49. PRICE HISTORY

Never mutate historical sale pricing because product price changed.

Snapshot:

    name
    SKU
    variant
    quantity
    unit price
    discount
    tax
    total

---

# 50. NEGATIVE STOCK

Default policy:

    BLOCK

Possible configured alternatives:

    WARN
    ALLOW

If allowed:

    record
    audit
    report

---

# 51. STOCK COUNT

Flow:

    Start
    ↓
    Snapshot expected
    ↓
    Physical count
    ↓
    Calculate discrepancy
    ↓
    Confirm
    ↓
    Adjustment event
    ↓
    Audit
    ↓
    Sync

---

# 52. CUSTOMER DUE

Derive from authoritative:

    receivable
    minus payments
    plus/minus credits as applicable

Do not store a manually editable final due as truth.

---

# 53. SUPPLIER PAYABLE

Derive from:

    purchases
    minus payments
    minus returns/credits as applicable

---
