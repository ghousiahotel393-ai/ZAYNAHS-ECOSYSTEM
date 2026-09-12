# AGENTS — OFFLINE-FIRST, LAN/P2P & FILE TRANSFER PROTOCOL

# 47. OFFLINE-FIRST

Offline operations should work where technically possible.

Examples:

    POS
    inventory
    products
    customers
    local reports
    chat queue
    file queue
    local CCTV
    local backup

Do not require Internet unnecessarily.

---

# 48. NETWORK ARCHITECTURE

Same LAN:

    direct peer connection where possible

Different network:

    rendezvous/signaling
        ↓
    WebRTC
        ↓
    direct P2P
        ↓
    TURN fallback

Cloud signaling is coordination only.

---

# 49. LARGE DATA

Do not send large:

    files
    videos
    CCTV
    product images

through signaling messages.

Use:

    WebRTC DataChannel
    object storage
    appropriate transfer path

---

# 50. FILE TRANSFER

Protocol:

    START
    META
    CHUNK
    ACK
    VERIFY
    COMPLETE

Support:

    resume
    retry
    cancel
    hash verification
    partial cleanup

---

# 51. FILE MEMORY

Never load an entire large file into RAM.

Use:

    streams
    bounded buffers
    chunks

---

# 52. FILE HASH

Use SHA-256 or established content hashing.

If receiver already has same hash:

    do not transfer duplicate content.

---

# 53. FILE PATH SECURITY

Never directly use received filenames as filesystem paths.

Prevent:

    path traversal
    absolute path injection
    unsafe characters

Use controlled internal storage paths.

---
