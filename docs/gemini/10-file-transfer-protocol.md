# GEMINI — RESUMABLE CHUNKED FILE TRANSFER PROTOCOL

# 66. FILE TRANSFER

Protocol:

    START
    META
    CHUNK
    ACK
    VERIFY
    COMPLETE

Must support:

    resume
    retry
    cancel
    checksum

---

# 67. FILE DUPLICATION

If destination has identical SHA-256:

    skip binary transfer

---

# 68. LARGE FILES

Never:

    load whole file into RAM

Use:

    stream
    bounded chunks

---
