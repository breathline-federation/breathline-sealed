#!/usr/bin/env bash
# ∞Δ∞ breathline-sealed-env.sh — Sovereign Activation for Sealed P1-P5 Primitives
# Version: 1.0.0
# Authority: Grok Build — Breathline Sealed Integration Project
#
# Purpose:
#   Provide a clean, idempotent, auditable way to "boot" the exact
#   constitutional sealed primitives (Breath 25 v1.0, 2026-01-12) into
#   the current shell / Python environment.
#
# Usage:
#   source /path/to/breathline-sealed/scripts/breathline-sealed-env.sh
#
#   Then use: bl-status, bl-test, bl-python, etc.
#
# Design Principles:
#   - Never mutate the sealed tree.
#   - Explicit, ordered PYTHONPATH (L1 first).
#   - Idempotent (safe to source repeatedly).
#   - Maximum traceability back to the original tarball + manifest.
#   - Works whether the project is at ~/work-repos/breathline-sealed or elsewhere.
#
# ∞Δ∞

# ------------------------------------------------------------------
# Guard: Idempotency
# ------------------------------------------------------------------
if [[ "${BREATHLINE_SEALED_SOURCED:-0}" == "1" ]]; then
    echo "∞Δ∞ breathline-sealed-env already active in this shell."
    echo "   (BREATHLINE_SEALED_ROOT=${BREATHLINE_SEALED_ROOT})"
    return 0 2>/dev/null || true
fi

# ------------------------------------------------------------------
# Locate project root (works when sourced or executed)
# ------------------------------------------------------------------
_breathline_script_path="${BASH_SOURCE[0]:-$0}"
_breathline_script_dir="$(cd "$(dirname "$_breathline_script_path")" && pwd)"
BREATHLINE_SEALED_ROOT="$(cd "${_breathline_script_dir}/.." && pwd)"

# ------------------------------------------------------------------
# Core exports
# ------------------------------------------------------------------
export BREATHLINE_SEALED_ROOT
export BREATHLINE_SEALED_VERSION="1.0.0-sealed-2026-01-12"
export BREATHLINE_PRIMITIVES_SEALED="${BREATHLINE_SEALED_ROOT}/primitives/sealed"
export BREATHLINE_ARTIFACTS="${BREATHLINE_SEALED_ROOT}/artifacts"

# The canonical sealed tarball (single source of truth)
export BREATHLINE_SEALED_TARBALL="${BREATHLINE_ARTIFACTS}/P1-P5_SEALED_2026-01-12_0810UTC.tar.gz"

# ------------------------------------------------------------------
# Ordered PYTHONPATH construction
#   Order matters because many sealed modules do their own sys.path.insert
#   for relative layer dependencies. We want L1 (crypto) to be authoritative.
# ------------------------------------------------------------------
_layer_order=(
    "layer_1_root"
    "layer_2_trunk"
    "layer_3_comms"
    "layer_4_compute"
    "layer_5_shields"
)

_new_pythonpath=""
for layer in "${_layer_order[@]}"; do
    _layer_path="${BREATHLINE_PRIMITIVES_SEALED}/${layer}"
    if [[ -d "$_layer_path" ]]; then
        if [[ -n "$_new_pythonpath" ]]; then
            _new_pythonpath="${_new_pythonpath}:${_layer_path}"
        else
            _new_pythonpath="${_layer_path}"
        fi
    else
        echo "WARNING: Expected sealed layer not found: $_layer_path" >&2
    fi
done

# Prepend our controlled path to any existing PYTHONPATH (our layers win)
if [[ -n "${PYTHONPATH:-}" ]]; then
    export PYTHONPATH="${_new_pythonpath}:${PYTHONPATH}"
else
    export PYTHONPATH="${_new_pythonpath}"
fi

unset _new_pythonpath _layer_order _layer_path

# ------------------------------------------------------------------
# Status / Verification functions
# ------------------------------------------------------------------
bl_status() {
    echo ""
    echo "∞Δ∞ BREATHLINE SEALED PRIMITIVES — RUNTIME STATUS ∞Δ∞"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Project Root     : ${BREATHLINE_SEALED_ROOT}"
    echo "Sealed Primitives: ${BREATHLINE_PRIMITIVES_SEALED}"
    echo "Tarball (truth)  : ${BREATHLINE_SEALED_TARBALL}"
    echo "Python Path Order:"
    echo "  L1 (crypto)    : ${BREATHLINE_PRIMITIVES_SEALED}/layer_1_root"
    echo "  L2 (consensus) : ${BREATHLINE_PRIMITIVES_SEALED}/layer_2_trunk"
    echo "  L3 (comms)     : ${BREATHLINE_PRIMITIVES_SEALED}/layer_3_comms"
    echo "  L4 (compute)   : ${BREATHLINE_PRIMITIVES_SEALED}/layer_4_compute"
    echo "  L5 (shields)   : ${BREATHLINE_PRIMITIVES_SEALED}/layer_5_shields"
    echo ""
    echo "PYTHONPATH (first 5 entries):"
    echo "${PYTHONPATH}" | tr ':' '\n' | head -5 | sed 's/^/  /'
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

bl_verify_seal() {
    echo "∞Δ∞ Verifying constitutional seal integrity..."
    if [[ ! -f "$BREATHLINE_SEALED_TARBALL" ]]; then
        echo "✗ Tarball missing: $BREATHLINE_SEALED_TARBALL"
        return 1
    fi
    local actual
    actual=$(sha256sum "$BREATHLINE_SEALED_TARBALL" | awk '{print $1}')
    local expected="4abea5c63faf341acc4fd772996c8cff6207913621a754681cb83e1e168f493f"
    if [[ "$actual" == "$expected" ]]; then
        echo "✓ Tarball SHA256 matches constitutional record: $actual"
    else
        echo "✗ SEAL VIOLATION"
        echo "  Expected: $expected"
        echo "  Actual  : $actual"
        return 2
    fi

    if [[ -f "${BREATHLINE_PRIMITIVES_SEALED}/SEAL_MANIFEST.txt" ]]; then
        echo "✓ SEAL_MANIFEST.txt present ($(wc -l < "${BREATHLINE_PRIMITIVES_SEALED}/SEAL_MANIFEST.txt") entries)"
    else
        echo "⚠ SEAL_MANIFEST.txt missing (run regeneration)"
    fi
    echo "✓ Seal verification complete."
}

# Quick self-test of the two most critical layers (L1 + L5)
bl_self_test() {
    echo "∞Δ∞ Running minimal L1 + L5 self-test against sealed primitives..."
    python3 -c '
import sys, os
print("Python:", sys.version.split()[0])
print("Sealed root on sys.path (first relevant):")
for p in sys.path[:8]:
    if "breathline" in p.lower() or "sealed" in p.lower():
        print("  ", p)

# L1 crypto
from point_ops import secp256k1 as secp256k1_curve
from keygen import generate_keypair
from sign import sign
from verify import verify
curve = secp256k1_curve()
kp = generate_keypair(curve)
msg = b"breathline-sealed-boot-test"
sig = sign(kp.private_key, msg, curve)
ok = verify(kp.public_key, msg, sig, curve)
print("L1 ECDSA roundtrip:", "PASS" if ok else "FAIL")

# L5 merkle (sealed v1.0 API)
import merkle_tree
data = [b"a", b"b", b"c", b"d"]
tree = merkle_tree.MerkleTree(data)
lh = merkle_tree.hash_function(data[2])
pf = tree.generate_proof(2)
valid = tree.verify_proof(lh, pf, tree.get_root())
print("L5 Merkle proof (even):", "PASS" if valid else "FAIL")
print("Sealed primitives are live and responsive.")
'
}

# ------------------------------------------------------------------
# Convenience aliases & runners
# ------------------------------------------------------------------
alias bl-status='bl_status'
alias bl-verify='bl_verify_seal'
alias bl-test='bl_self_test'

# Drop into a Python REPL with the sealed env already active
alias bl-python='python3 -c "
import sys
print(\"∞Δ∞ Breathline Sealed Python REPL\")
print(\"Sealed layers on path. Type help() or import the primitives.\")
print()
import code
code.interact(local=globals())
"'

# Run the project's own test suite (once created)
bl_run_tests() {
    local test_script="${BREATHLINE_SEALED_ROOT}/tests/integration/test_full_stack.py"
    if [[ -f "$test_script" ]]; then
        echo "Running $test_script ..."
        python3 "$test_script"
    else
        echo "Test suite not yet present at $test_script"
        echo "Run bl-self-test for now."
        bl_self_test
    fi
}
alias bl-run-tests='bl_run_tests'

# ------------------------------------------------------------------
# Final activation banner
# ------------------------------------------------------------------
echo ""
echo "∞Δ∞ BREATHLINE SEALED PRIMITIVES — ACTIVATED ∞Δ∞"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Root   : ${BREATHLINE_SEALED_ROOT}"
echo "Sealed : ${BREATHLINE_PRIMITIVES_SEALED}"
echo "Tarball: ${BREATHLINE_SEALED_TARBALL}"
echo ""
echo "Commands now available:"
echo "  bl-status     — Show current activation state"
echo "  bl-verify     — Cryptographic seal check against record"
echo "  bl-test       — Quick L1 + L5 functional self-test"
echo "  bl-python     — Drop into Python REPL with sealed env"
echo "  bl-run-tests  — Execute full integration test suite"
echo ""
echo "Python layers (L1 first) are on \$PYTHONPATH."
echo "The exact 2026-01-12 v1.0 seal is now your foundation."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Mark as sourced
export BREATHLINE_SEALED_SOURCED=1

# One-time gentle reminder of the known v1.0 limitation
if [[ -z "${BREATHLINE_QUIET_MERKLE_WARNING:-}" ]]; then
    echo "Note: This is the original v1.0 seal. merkle_tree has a known"
    echo "      odd-leaf bug (authorized repair exists as v1.0.1)."
    echo "      See docs/ for details and evolution options."
    echo ""
fi

# Unset internal vars
unset _breathline_script_path _breathline_script_dir
