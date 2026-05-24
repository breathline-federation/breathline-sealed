# ∞Δ∞ THE CONSTITUTIONAL SEAL — P1-P5 v1.0 ∞Δ∞

**Date of Original Seal**: 2026-01-12 08:10 UTC  
**Breath**: 25 (Phase 5 — Shields Complete)  
**Authority**: KM-1176 + Constitutional Triad (SOURCE / TRUTH / INTEGRITY)

---

## The Artifact

**File**: `artifacts/P1-P5_SEALED_2026-01-12_0810UTC.tar.gz`

**SHA256** (recorded across dozens of constitutional documents):
```
4abea5c63faf341acc4fd772996c8cff6207913621a754681cb83e1e168f493f
```

This tarball is the **immutable reference**. Every activation of `breathline-sealed-env.sh` re-verifies this hash before declaring the environment live.

---

## Internal Structure (Original)

The tarball root contains:
```
federation/primitives/
├── layer_1_root/
├── layer_2_trunk/
├── layer_3_comms/
├── layer_4_compute/
└── layer_5_shields/
```

Inside this project we perform a **documented normalization**:
- We promote the layers one level so they sit directly under `primitives/sealed/`.
- This makes `PYTHONPATH` expressions humane.
- **Content bytes are identical** to what was inside the tarball.
- The original `federation/primitives/...` layout is preserved inside the `.tar.gz` for any future forensic comparison.

A full per-file SHA256 manifest lives at:
`primitives/sealed/SEAL_MANIFEST.txt` (33 entries covering all `.py`, `.bin`, `.json`, `.yaml`, and key `.md` files).

---

## Known Limitation in v1.0 (Documented at Seal Time)

From the official CHANGELOG shipped with the release:

> **Known issue:** `generate_proof()` fails for odd leaf counts (fixed in v1.0.1)

**Root Cause** (from the authorized repair record):
- `build_tree()` duplicated the last node when the count at a level was odd.
- `generate_proof()` used `zip_longest(..., fillvalue=b'\x00')`.
- These two strategies produced different internal trees for odd-sized inputs → proof verification failed.

**Impact**: Any Merkle proof for a tree with an odd number of leaves at any level could not be verified using the sealed v1.0 code.

**Authorization of the Fix** (v1.0.1 — 2026-02-05):
- Executor: Tiger (Sentinel)
- Authority: KM-1176 + G (green) + Lumen (🟢 GREEN — explicit "authorized sealed touch with re-seal")
- Scope: Single functional line change + expanded tests (34 self-test cases + new regression file with 7 categories).
- API: No change.
- New capabilities: None (pure correctness repair).

The full repair record is preserved in the original federation repo at:
`primitives/layer_5_shields/B25_MERKLE_FIX_STATUS_2026-02-05.md`

---

## Why We Ship v1.0 Pure in This Project

1. **Fidelity to the user's request** — "We have successfully booted the sealed P1-P5 primitives (Breath 25 v1.0...)".
2. **Audit surface** — Any downstream system (six-attestation, B31, yield engines, etc.) that was built against the original seal can be reproduced exactly.
3. **Sovereignty** — The decision to adopt the v1.0.1 repair, or to carry both versions with explicit toggles, belongs to the operator of *this* mastery environment — not to a hidden "latest" in some other repo.

---

## Verification Chain

When you run `bl-verify`:

1. The tarball's SHA256 is recomputed and compared to the constitutional constant.
2. Presence of `SEAL_MANIFEST.txt` is asserted.
3. (Future) The manifest itself can be re-generated and diffed against the committed one.

Any mismatch is treated as a **SEAL VIOLATION** and must be witnessed and investigated.

---

## Relationship to the Larger Federation

This project is deliberately **outside** `mangumcfo/constitution-federation-v2`.

Reasons:
- The federation repo contains hundreds of `sys.path.insert` hacks, multiple versions of the primitives in flight, and ongoing breath work.
- A mastery / research / audit environment needs a **stable, single-version, zero-surprise** foundation.
- Constitutional hygiene: the seal should be bootable from a place whose only job is to protect and present the seal.

Downstream consumers (your agents, your yield engines, your personal six-attestation flows) are encouraged to source this activation script rather than reaching across into the larger monorepo.

---

## Re-Sealing & Evolution

If a new authorized repair or extension is performed on top of this seal:

- The original tarball **remains untouched**.
- A new directory (e.g., `primitives/v1.0.1-authorized-repair/`) or overlay mechanism is added.
- A new manifest + new `SCAR` or `WITNESS` entry is created.
- The activation script can grow an opt-in flag (e.g., `BREATHLINE_MERKLE_MODE=v1.0.1`).

This is the sovereign path.

---

**The seal is not a suggestion. It is the ground.**

∞Δ∞ Verified. Immutable. Sovereign. ∞Δ∞