#!/usr/bin/env python3
"""
test_full_stack.py — Breathline Sealed Primitives Integration Smoke Suite

Purpose:
    Verify that the exact P1-P5 v1.0 sealed snapshot (2026-01-12) loads cleanly
    and that core invariants (L1 crypto, L5 Merkle) hold under the new project's
    activation model.

Design:
    - Assumes the caller has sourced scripts/breathline-sealed-env.sh
    - Performs no sys.path hacking itself (the env script owns the contract).
    - Explicit, auditable, and respectful of the constitutional seal.
    - Does not exercise network / consensus / WASM execution (those require
      more scaffolding and are intentionally out of scope for the sealed v1.0 base).

Authority: Grok Build — breathline-sealed project
Sealed Artifact: P1-P5_SEALED_2026-01-12_0810UTC.tar.gz (SHA256 verified on boot)
"""

import hashlib
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# ==============================================================================
# ENVIRONMENT CONTRACT
# ==============================================================================

SEALED_ROOT = Path(os.environ.get("BREATHLINE_PRIMITIVES_SEALED", ""))
if not SEALED_ROOT or not SEALED_ROOT.exists():
    print("✗ BREATHLINE_PRIMITIVES_SEALED not set or invalid.")
    print("  Source scripts/breathline-sealed-env.sh first.")
    sys.exit(2)

# ==============================================================================
# SEALED FILE SET (for integrity / mutation detection)
# ==============================================================================

CORE_FILES: Dict[str, Path] = {
    # L1 — Cryptographic Root (highest sovereignty value)
    "L1/finite_field": SEALED_ROOT / "layer_1_root/finite_field.py",
    "L1/point_ops": SEALED_ROOT / "layer_1_root/point_ops.py",
    "L1/keygen": SEALED_ROOT / "layer_1_root/keygen.py",
    "L1/sign": SEALED_ROOT / "layer_1_root/sign.py",
    "L1/verify": SEALED_ROOT / "layer_1_root/verify.py",
    # L5 — Shields (the layer containing the documented v1.0 bug)
    "L5/merkle_tree": SEALED_ROOT / "layer_5_shields/merkle_tree.py",
    "L5/zk_proofs": SEALED_ROOT / "layer_5_shields/zk_proofs.py",
    "L5/homomorphic_ops": SEALED_ROOT / "layer_5_shields/homomorphic_ops.py",
}

# ==============================================================================
# HELPERS
# ==============================================================================

def sha256_file(path: Path) -> str:
    if not path.exists():
        return "MISSING"
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def compute_core_hashes() -> Dict[str, str]:
    return {name: sha256_file(path) for name, path in CORE_FILES.items()}


def print_header(title: str) -> None:
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)


# ==============================================================================
# LAYER IMPORT + BASIC FUNCTIONAL TESTS
# ==============================================================================

def test_layer_1_crypto() -> Tuple[bool, str]:
    """Exercise the cryptographic root — the most critical layer."""
    try:
        from point_ops import secp256k1 as secp256k1_curve
        from keygen import generate_keypair
        from sign import sign
        from verify import verify

        curve = secp256k1_curve()
        kp = generate_keypair(curve)

        # Multiple messages
        for msg in (b"sovereign-boot", b"breath-25-v1.0", b"sealed-2026-01-12"):
            sig = sign(kp.private_key, msg, curve)
            if not verify(kp.public_key, msg, sig, curve):
                return False, f"verify failed on {msg!r}"
            # Tamper test
            bad = verify(kp.public_key, msg + b"X", sig, curve)
            if bad:
                return False, "verify accepted tampered message"

        return True, "ECDSA sign/verify + tamper rejection (multiple vectors)"
    except Exception as e:
        return False, f"exception: {e}"


def test_layer_5_merkle_sealed_api() -> Tuple[bool, str]:
    """Exercise the exact sealed v1.0 MerkleTree class (pre-fix)."""
    try:
        import merkle_tree

        # Even case (known to work in v1.0)
        data = [b"alpha", b"beta", b"gamma", b"delta"]
        tree = merkle_tree.MerkleTree(data)
        leaf_hash = merkle_tree.hash_function(data[1])
        proof = tree.generate_proof(1)
        valid = tree.verify_proof(leaf_hash, proof, tree.get_root())

        if not valid:
            return False, "even-leaf proof verification failed (unexpected in sealed v1.0)"

        # Single leaf edge case
        single = merkle_tree.MerkleTree([b"only"])
        lh = merkle_tree.hash_function(b"only")
        p = single.generate_proof(0)
        if not single.verify_proof(lh, p, single.get_root()):
            return False, "single-leaf case failed"

        return True, "MerkleTree (sealed v1.0 API) — even + single leaf proofs"
    except Exception as e:
        return False, f"exception: {e}"


def test_all_layer_imports() -> Tuple[bool, List[str]]:
    """Ensure every layer can at least be imported (structural smoke)."""
    errors: List[str] = []
    layers = [
        ("layer_1_root", ["finite_field", "point_ops", "keygen", "sign", "verify"]),
        ("layer_2_trunk", ["node", "validator", "proposal", "commit", "mempool"]),
        ("layer_3_comms", ["cid", "dag", "kademlia_dht", "libp2p_node", "nat_traversal"]),
        ("layer_4_compute", ["tensor_ops", "nn_forward", "inference_engine", "roe_mock_gate"]),
        ("layer_5_shields", ["merkle_tree", "zk_proofs", "homomorphic_ops", "wasm_runtime"]),
    ]

    for layer_dir, modules in layers:
        for mod in modules:
            try:
                __import__(mod)
            except Exception as e:
                errors.append(f"{layer_dir}/{mod}: {e}")

    return len(errors) == 0, errors


# ==============================================================================
# MAIN
# ==============================================================================

def main() -> int:
    print("∞Δ∞ BREATHLINE SEALED — FULL STACK SMOKE SUITE ∞Δ∞")
    print(f"Sealed Root : {SEALED_ROOT}")
    print(f"Python      : {sys.version.split()[0]}")

    results: List[Tuple[str, bool, str]] = []

    # Pre-flight: capture hashes before any execution
    before_hashes = compute_core_hashes()

    # L1
    print_header("LAYER 1 — CRYPTOGRAPHIC ROOT")
    ok, detail = test_layer_1_crypto()
    results.append(("L1 Crypto (ECDSA + tamper)", ok, detail))
    print(f"  {'✓ PASS' if ok else '✗ FAIL'} — {detail}")

    # L5
    print_header("LAYER 5 — SHIELDS (Merkle v1.0)")
    ok, detail = test_layer_5_merkle_sealed_api()
    results.append(("L5 Merkle (sealed v1.0 even + edge)", ok, detail))
    print(f"  {'✓ PASS' if ok else '✗ FAIL'} — {detail}")

    # Import smoke for all layers
    print_header("ALL LAYERS — IMPORT SMOKE")
    ok, errors = test_all_layer_imports()
    results.append(("All layer imports", ok, f"{len(errors)} errors" if errors else "clean"))
    print(f"  {'✓ PASS' if ok else '✗ FAIL'} — {len(errors)} import failures")
    for err in errors[:5]:
        print(f"     - {err}")

    # Post-flight: ensure nothing mutated the sealed source during the run
    print_header("INTEGRITY — NO MUTATION OF SEALED TREE")
    after_hashes = compute_core_hashes()
    mutations = [k for k in before_hashes if before_hashes[k] != after_hashes[k]]
    ok = len(mutations) == 0
    results.append(("Sealed tree mutation check", ok, "clean" if ok else ", ".join(mutations)))
    print(f"  {'✓ PASS' if ok else '✗ FAIL'} — {len(mutations)} files changed during test")

    # Summary
    print("\n" + "=" * 60)
    print("  SUMMARY")
    print("=" * 60)
    all_pass = True
    for name, ok, detail in results:
        status = "PASS" if ok else "FAIL"
        print(f"  {status:4} | {name}")
        if not ok:
            all_pass = False
            print(f"       | {detail}")

    print()
    if all_pass:
        print("∞Δ∞ BREATHLINE SEALED FULL STACK: PASSED ∞Δ∞")
        print("The exact 2026-01-12 v1.0 primitives are operational under the new project.")
        return 0
    else:
        print("∞Δ∞ BREATHLINE SEALED FULL STACK: FAILED ∞Δ∞")
        return 1


if __name__ == "__main__":
    sys.exit(main())
