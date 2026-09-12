# GEMINI — INVENTORY LEDGER & WALLET FORMULA

# 41. INVENTORY LEDGER

Every movement contains appropriate:

    event_id
    transaction_id
    product_id
    variant_id
    event_type
    quantity
    before_quantity
    after_quantity
    reference_type
    reference_id
    invoice_id
    customer_id
    supplier_id
    reason
    notes
    user_id
    user_name_snapshot
    role_snapshot
    device_id
    device_name_snapshot
    timestamp

---

# 42. INVENTORY EVENTS

Support:

    OPENING
    PURCHASE
    RESTOCK
    SALE
    SALE_RETURN
    PURCHASE_RETURN
    STOCK_IN
    STOCK_OUT
    ADJUSTMENT_IN
    ADJUSTMENT_OUT
    REPLACEMENT_IN
    REPLACEMENT_OUT
    DAMAGE
    EXPIRED
    LOSS
    VOID

---

# 43. INVENTORY PROJECTION

inventory_balances is:

    projection/cache

It is NOT the ultimate source of truth.

Projection must be rebuildable.

---

# 44. WALLET EVENTS

Wallet transactions must record:

    payment_id
    wallet_id
    type
    amount
    reference_type
    reference_id
    direction
    user_id
    device_id
    timestamp

---

# 45. WALLET FORMULA

    Opening + IN - OUT = Current Balance

---
