# AGENTS — FINANCIAL REPORTS, EXPORTS, PRINTING & BARCODES

# 92. REPORTS

Reports must derive from authoritative data.

Do not calculate financial reports from:

    UI counters
    cached wallet balance alone
    stale inventory projection

---

# 93. REPORT FILTERS

Support as applicable:

    date
    user
    device
    product
    category
    payment method
    transaction type
    customer
    supplier

---

# 94. EXPORTS

Support:

    CSV
    XLSX
    PDF
    print

Large exports should use:

    streaming
    batching
    pagination

where appropriate.

---

# 95. PRINTING

Shared architecture:

    PrintJob
      ↓
    Template Engine
      ↓
    Layout Renderer
      ↓
    Target Adapter

Targets:

    thermal
    PDF
    Windows
    Web
    A4
    labels

---

# 96. BARCODE

Support where required:

    Code 128
    EAN-13
    EAN-8
    UPC-A
    Code 39
    ITF-14
    QR

Validate:

    format
    uniqueness
    check digit where applicable

---
