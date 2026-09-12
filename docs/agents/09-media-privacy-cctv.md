# AGENTS — PRIVACY (CAMERA/MIC/SCREEN/LOCATION) & CCTV

# 54. CAMERA SECURITY

Camera operations must be:

    explicit
    visible
    permission-controlled
    revocable

No covert camera capture.

---

# 55. MICROPHONE SECURITY

Microphone operations must be:

    explicit
    visible
    permission-controlled
    revocable

No covert microphone recording.

---

# 56. LOCATION SECURITY

Location operations must be:

    permission-controlled
    visible
    revocable

No hidden tracking.

---

# 57. SCREEN SHARING

Screen sharing must require:

    explicit user action
    platform permission
    visible active state

Stop immediately when revoked/cancelled.

---

# 58. CCTV

CCTV may use:

    USB cameras
    IP cameras
    RTSP
    authorized device camera source

Recording must be transparent and authorized.

---

# 59. CCTV PIPELINE

    Camera
      ↓
    Capture
      ↓
    Live
      ↓
    Recording
      ↓
    Local Storage
      ↓
    Metadata
      ↓
    Playback

Optional:

    low-resolution detection stream

---

# 60. CCTV RECORDING

Do not hold full recording in RAM.

Use:

    segments
    streaming writes
    safe finalization
    metadata
    hash
    atomic rename

---

# 61. CCTV SEGMENTS

Recommended:

    1–5 minute segments

Example:

    camera-001/
        2026/
            09/
                13/
                    00-00-00_00-05-00.mp4

---

# 62. CCTV CODECS

Prefer:

    H.264

Use:

    H.265/HEVC

where supported and appropriate.

Avoid unnecessary transcoding.

---

# 63. CCTV RETENTION

Retention cleanup must NEVER delete:

    protected recordings
    active recordings
    required audit evidence
    in-progress operations

Storage pressure must be handled safely.

---

# 64. CCTV DETECTION

Detection should preferably use:

    lower-resolution stream

Events:

    motion
    person
    vehicle
    object

Store:

    event metadata
    timestamp
    confidence
    optional snapshot

Do not duplicate full video unnecessarily.

---

# 65. CCTV RESOURCE CLEANUP

Release:

    camera handles
    microphone handles
    video encoders
    sockets
    streams
    buffers

when no longer needed.

---
