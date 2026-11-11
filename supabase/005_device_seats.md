# Mac seat binding (1 / 2 / 5 Macs)

## Model
- License row `iclearer_licenses.macs` is the seat limit (1, 2, or 5).
- Each activation inserts a row in `iclearer_devices` keyed by `(license_id, device_hash)`.
- `device_hash` is SHA-256 of the Mac’s `IOPlatformUUID` (not the raw serial). Same Mac = same seat.
- Activate on a new Mac when seats are full → HTTP 409 until a device is removed.
- Heartbeat / offline blob requires that this Mac already has a device row.

## Why not raw serial?
Industry practice (LicenseFlow, Keylight, LicenseManager): fingerprint with a stable machine UUID, hash it, never store cleartext hardware serials. `IOPlatformUUID` survives OS reinstalls and changes when the logic board is replaced.

## Customer flow
1. Buy plan with N Macs on the website.
2. Sign in on Mac → activate claims one seat.
3. Account → Your Macs lists seats; Remove frees a seat for another Mac.
