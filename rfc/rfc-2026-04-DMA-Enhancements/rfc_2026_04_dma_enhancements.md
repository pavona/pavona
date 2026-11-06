# Request For Comments 2026-04: DMA Enhancements

* Status: Proposed
* Authors: [Robert Schilling](mailto:schilling.ro@gmail.com)
* Last Updated: July 6, 2026

## Summary

Four incremental changes to the DMA controller:

1. **Generic host ports** - make the DMA portable across tops.
2. **Throughput** - remove wasted per-beat cycles.
3. **Inline AES-CTR/GCM** - encrypt/decrypt data in flight.
4. **Memset** - initialize memory without requiring a source buffer.

Each lands on its own.
Together they make the DMA reusable across tops, significantly improve throughput, add inline authenticated encryption, and accelerate memory initialization.

## Motivation

Today the DMA has a bespoke, top-specific port set, a strictly serial per-beat FSM, no inline crypto, and no hardware support for memory initialization.
That blocks reuse, wastes bus cycles, forces an extra copy through software for encrypted transfers, and requires CPU involvement for large memory fills.

## Prerequisites

Inline AES-GCM depends on the AES core supporting GCM.
Pavona's `aes_core` does not have GCM yet, so GCM must first be ported.
This is a standalone task that lands before the inline-AES change.
The other tasks of this RFC don't have any prerequisites.

## Proposal

### 1. Generic host ports

- Replace the hardcoded host/ctn/sys ports with an ASID-indexed TL-UL host port array driven by an ACE `PortDesc` descriptor (same pattern as KMAC `AppCfg`). The existing custom 64-bit system port becomes a standard 64-bit TL-UL host port.
- Two boundary classes: `NumTlul32` 32-bit TL-UL host ports and `NumTlul64` 64-bit TL-UL host ports. Per-port `count` and zero-count are supported.
- reggen/topgen gain `count: N` host vectors with mixed crossbar and point-to-point routing.

### 2. Throughput

Two independent datapath changes:

- **AddrSetup once per chunk.**
  The FSM re-ran address computation and the full config/error check on *every* beat.
  Do it once per chunk and compute the next beat's address/byte enables inline.
  This saves one cycle per beat and pulls the config decode out of the per-beat critical path.
  It is ~8–33% faster, with the largest gains for fast memory.

- **Read/Write overlap.**
  For cross-port copies, read beat *i+1* while writing beat *i*, via two hand-off buffers and per-direction in-flight tracking.
  This is ~2× faster on cross-port, engine-bound copies.
  Same-port copies stay serial, since one physical port cannot do both at once.

### 3. Inline AES-CTR/GCM

Depends on the AES-GCM port to Pavona.

- Embed `aes_core` (CTR + GCM/GHASH, DOM-masked) behind a streaming wrapper.
  Gather → process → scatter reuses the read → capture → write hand-off above.
- Orthogonal CONTROL (`aes_op`, `aes_mode`) with key/IV/AAD and TAG registers.
  The GCM tag uses a fail-closed redundant compare and raises a recoverable alert on mismatch.
- Security: key/IV/AAD/tag are wiped on completion, abort, or error; the key can come from keymgr sideload; and a decrypted result is quarantined until the tag verifies (no DONE on mismatch).

### 4. Memset

- Add a dedicated `memset` DMA operation to efficiently initialize memory without requiring a source buffer.
- The existing source address register, which is unused by `memset`, is repurposed to hold the fill value.
- The engine replicates the fill value across each transfer beat, allowing memory to be initialized at DMA bandwidth with no read traffic.
- This reduces memory bandwidth, eliminates unnecessary source-buffer allocations, and avoids CPU involvement for large memory initialization.

## Compatibility

This RFC proposes DMA interface version 2.0.

The opcode encoding changes to support the new operations and functionality.
In addition, all host port interfaces are standardized on TL-UL, replacing the existing custom system interface.
Existing DMA software and integrations must be updated accordingly.
