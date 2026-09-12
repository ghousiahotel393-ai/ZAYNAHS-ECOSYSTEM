# GEMINI — MEDIA PRIVACY & CCTV RECORDING PIPELINE

# 59. CCTV TRANSPARENCY

CCTV functionality must always be:

    authorized
    visible
    permission-controlled

No covert monitoring.

---

# 60. DEVICE CAMERA

Phone camera sharing must:

    request permission
    show active state
    be user-controlled
    stop when revoked

---

# 61. SCREEN SHARE

Must use platform-approved screen capture permission.

Never silently capture screen.

---

# 62. LOCATION

Location must be:

    permission-based
    visible
    revocable

Do not fabricate current location.

---

# 63. CCTV STORAGE

Recording write flow:

    temp
    ↓
    flush/finalize
    ↓
    hash
    ↓
    metadata
    ↓
    atomic rename
    ↓
    complete

---

# 64. CCTV RECORDING METADATA

Store:

    recording_id
    camera_id
    start
    end
    file_path
    size
    hash
    status
    codec
    resolution
    fps
    protected

---

# 65. CCTV DETECTION

Use separate low-resolution stream where possible.

Events:

    motion
    person
    vehicle
    object

Store metadata/snapshots where configured.

---
