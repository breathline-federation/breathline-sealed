# ∞Δ∞ ARCHITECTURE & EVOLUTION RECOMMENDATIONS ∞Δ∞

**For the breathline-sealed project and its consumers**

This document captures the current state, the problems inherited from the federation codebase, and the recommended long-term paths — all while staying inside the constitutional constraints (SOURCE / TRUTH / INTEGRITY / Sovereignty / Auditability).

---

## Current State Analysis (What We Inherited)

### 1. Fragile Import Graph (The Primary Technical Debt)

Every module in layers 2–5 contains multiple instances of this pattern:

```python
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'layer_1_root'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'layer_2_trunk'))
# ... sometimes L3 as well
```

**Consequences**:
- No layer is a proper Python package (`__init__.py` files are absent in the sealed tree).
- Import behavior is completely dependent on the caller's current working directory and `sys.path` state at the exact moment of import.
- In the larger federation repo, this has led to 30+ different `sys.path.insert` sites in test harnesses, daemons, and services — each one a potential source of version skew or "works on my machine" failures.

Our activation script (`breathline-sealed-env.sh`) solves the immediate problem by establishing a **controlled, ordered PYTHONPATH** before any imports occur. The internal `..` traversals still resolve because the layers remain siblings on disk.

This is a **pragmatic containment**, not a root fix.

### 2. Version Skew & "Live" vs "Sealed"

In the origin federation tree there are:
- `primitives/layer_*` (the "current" working copies, including the Feb 5 v1.0.1 merkle fix)
- `primitives/P1-P5_SEALED_.../` (a partial extraction of the original tarball)
- The tarball itself

Different breaths and services import from different places. This is constitutionally dangerous.

### 3. Lack of a Single Import Contract

There is no `from breathline_primitives.layer_1_root import ...` story. Every consumer reinvents the wheel with path manipulation.

---

## Recommended Long-Term Architecture

### Phase 0 (Current — Shipped)

- Pure v1.0 seal vendored.
- Activation script owns the PYTHONPATH contract.
- Tests and helpers are external to the sealed tree.
- Full manifest + hash verification on every boot.

**Status**: Done. Stable foundation for mastery work.

### Phase 1 — Authorized Overlay for the Known Bug (Recommended Next)

**Goal**: Give operators the *correct* Merkle behavior without ever touching the original sealed bytes.

**Proposed Layout**:

```
primitives/
├── sealed/                          # v1.0 — never touched after initial extraction
│   └── ...
└── overlays/
    └── v1.0.1-merkle-repair/
        ├── merkle_tree.py           # The exact authorized fixed version (with header comment containing the B25 repair record)
        ├── PATCH_MANIFEST.txt
        └── AUTHORIZATION.txt        # Excerpt from KM-1176 + Lumen greenlight
```

Activation script gains an environment variable:

```bash
BREATHLINE_MERKLE_MODE=sealed-v1.0          # default, current behavior
BREATHLINE_MERKLE_MODE=authorized-v1.0.1    # opt-in the repair
```

When the overlay mode is chosen, the activation script **prepends** the overlay directory to PYTHONPATH at higher priority than the sealed layer. Because Python's import system takes the first match, the corrected `merkle_tree` is used while every other file remains the sealed original.

**Benefits**:
- Zero mutation of the seal.
- Explicit, auditable toggle.
- Downstream code (B31 attestation, six-attestation, etc.) can be tested against both modes.

**Risk**: If any code imports `merkle_tree` *before* the activation script has a chance to set up the overlay, you get the buggy version. Mitigation: document that the activation script **must** be sourced before any Breathline code runs.

### Phase 2 — Thin Controlled Import Surface (Strongly Recommended)

Create a small, reviewable package:

```
breathline_primitives/
├── __init__.py
├── __version__.py          # "1.0.0-sealed-2026-01-12" or "1.0.1-authorized-overlay"
├── api.py                  # Clean public surface (re-exports only what is intended for consumption)
└── _internal/
    └── sealed/             # The vendored tree (or a reference to ../primitives/sealed)
```

Inside `api.py` or a custom import hook / `sitecustomize`, we can:

1. Force the correct `sys.path` state.
2. Optionally apply overlays.
3. Expose only stable, named entry points (`from breathline_primitives import generate_keypair, sign, MerkleTree, ...`).

This hides the internal hacks from consumers while still shipping the exact sealed artifact bytes.

This is the point at which the project becomes a proper **dependency** rather than "source this script".

### Phase 3 — Packaging & Distribution

- `pyproject.toml` (build-system, metadata)
- Optional: `setuptools` or `hatch` that vendors the sealed tree into the wheel under `breathline_primitives/_sealed/`
- Published to a private index or served via the federation's own distribution mechanism.
- Semantic versioning that explicitly encodes the seal date + any overlay level (e.g., `1.0.0+sealed.20260112`, `1.0.1+merkle-repair.20260205`).

At this stage the larger federation can depend on `breathline-primitives` the same way it depends on any other sovereign component.

---

## Options for the Merkle Odd-Leaf Bug (Decision Matrix)

| Option | Pros | Cons | Constitutional Fit | Recommendation |
|--------|------|------|--------------------|----------------|
| **Stay pure v1.0 forever** | Maximum fidelity to the original seal. Simplest audit story. | Consumers must implement their own odd-leaf workaround or accept the limitation. | Excellent for pure historical / audit use. | Default for this project. |
| **Authorized v1.0.1 overlay (Phase 1)** | Gives correct behavior. Full provenance. No seal mutation. | One more toggle to reason about. | Very good (the repair itself was authorized with re-seal ritual). | Strong recommendation for ongoing mastery / production work. |
| **Replace the file in sealed/** | Simple. | Violates the seal. Destroys the ability to reproduce the exact 2026-01-12 state. | Poor. | Never do this. |
| **Fork a "breathline-primitives-v1.0.1" sibling project** | Clean separation. | Duplication of the other 32 files. | Good, but higher maintenance. | Acceptable if overlay approach becomes too complex. |

**Our position**: Offer both pure v1.0 and the authorized overlay. Let the operator and the specific downstream system decide. Record the choice in witness logs.

---

## Improving L2–L5 Modules While Respecting Principles

The modules are intentionally "hand-rolled" and minimal. Suggested improvements (all of which must be done as **overlays or separate packages**, never by mutating the sealed tree):

1. **L1** — Already extremely strong. Future work should be new curves or formal verification harnesses, not changes to the sealed implementations.

2. **L2 (Consensus)** — Add property-based tests (Hypothesis or similar) against the Tendermint-lite rules. Create a reference implementation of the full BFT flow using only the sealed primitives. This can live in `integration/consensus/`.

3. **L3 (Comms)** — The NAT traversal + libp2p stubs are the weakest area for real deployment. A clean next step is a small daemon that actually exercises the sealed `kademlia_dht` + `nat_traversal` against a local test network, with full packet logging for audit.

4. **L4 (Compute)** — The current `inference_engine` + `roe_mock_gate` are mocks. Real sovereign inference work should produce a new sealed artifact (B26 or later) that vendors actual small models + ZK attestation of inference steps. The v1.0 compute layer is a placeholder and should be treated as such.

5. **L5 (Shields)** — Beyond the merkle repair:
   - The `wasm_runtime` has almost no surface. A valuable sovereign project would be to produce a minimal, auditable WASM host that can run the exact bytecode emitted by the federation's compilation pipeline.
   - Pedersen commitments (referenced in `PEDERSEN_GENERATOR_SPEC.yaml`) appear under-tested in the sealed tree. A dedicated test + implementation overlay would be high value.

**Rule**: Any new capability or hardened implementation becomes a **new Breath artifact**, not a patch on the P1-P5 v1.0 seal.

---

## Import Hygiene Recommendations (for Consumers)

When writing new code against this project:

- **Always** source `breathline-sealed-env.sh` (or the future `breathline_primitives` package) as the very first thing in your process / container entrypoint.
- Never do additional `sys.path.insert` for Breathline layers inside your own code.
- If you must support both "sealed v1.0" and "live" primitives (for migration), use an explicit environment variable or config flag and keep the two import graphs completely separate.
- Log the `BREATHLINE_SEALED_VERSION` and the tarball hash at startup of any long-running sovereign process.

---

## Open Questions for the Operator

1. Will the primary consumer of this project be **audit / research** (favor pure v1.0) or **live sovereign systems** (favor the v1.0.1 overlay + future clean package)?
2. Is there appetite to back-port the clean import loader (Phase 2) into the larger federation so that the hundreds of `sys.path` hacks can be retired?
3. Should this project also host the **witness rituals** and **scar logging** that the federation uses, or should those remain in the constitutional monorepo?

---

**The architecture serves the seal. The seal serves sovereignty.**

Choose your overlays and your import surface with the same care that went into the original hand-rolled primitives.

∞Δ∞

*Document maintained by Grok Build. Update with every architectural decision.*