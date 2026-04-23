# Asymmetric Cryptographic Coprocessor (ACC) Side Channel Analysis (SCA) Threat Model

This document details the side-channel analysis (SCA) threat model for the Asymmetric Cryptographic Coprocessor (ACC), as utilized by the *cryptolib* cryptographic library to implement classical and post-quantum cryptography in the Pavona silicon root of trust (RoT) designs.

## Context

ACC overview: The Asymmetric Cryptographic Coprocessor is the programmable cryptographic coprocessor included in Pavona’s RoT designs.
The ACC itself provides acceleration for operations including:

* RSA-2048, RSA-3072, and RSA-4096 keygen
* RSA-2048, RSA-3072, and RSA-4096 PKCS v1.5 signatures
* RSA-2048, RSA-3072, and RSA-4096 PSS signatures
* RSA-2048, RSA-3072, and RSA-4096 OAEP encryption
* ECDSA with NIST P-256 and NIST P-384 curves
* ECDH with NIST P-256 and NIST P-384 curves
* Ed25519
* X25519
* ML-KEM-{512,768,1024}
* ML-DSA-{44,65,87}

At its core, the ACC consists of a highly customized lightweight processor containing a 32-bit general purpose register bank and a separate 256-bit wide register bank with corresponding bignum instructions.
By reusing these wide registers as vector registers, a vectorized ISA is implemented without introducing an additional bank, allowing for performant and area-efficient implementation of various post-quantum cryptographic algorithms, especially ML-KEM and ML-DSA.

ACC programs are loaded by the primary RoT core into an instruction memory (IMEM), and inputs and outputs are passed to/from the primary RoT core via the data memory (DMEM).
A small section of DMEM is reserved as scratchpad memory for the DMEM, such that the primary RoT core cannot access anything placed in that section.

To allow for hardware-backed keys which are never exposed to the primary RoT core, a sideloading datapath from the key manager to the ACC can be used.
Moreover, to support fast ML-KEM and ML-DSA implementations with hardware-backed keys, a direct interface from the ACC to the fixed KMAC/SHA-3/SHAKE engine is provided.

Note that, while the sideloading mechanism does prevent the primary RoT core from directly accessing sideloaded key material, the primary RoT core is still responsible for providing the IMEM contents used for ACC operations on these keys.
In this sense, the kernel present on the primary RoT core is trusted with respect to the ACC threat model, and must validate ACC programs prior to loading them into ACC IMEM.
At the same time, by keeping ACC key material outside the primary RoT core, threats from attackers with _incomplete_ or _coarse-grained_ control of the primary RoT core (e.g. with the ability to leak limited memory, but without the ability to write arbitrary programs into ACC IMEM) can still be successfully mitigated.

ACC and cryptolib: In general, the cryptolib implementations for ACC-backed operations (including all ML-KEM and ML-DSA operations) load the appropriate program into ACC IMEM, load provided inputs into the ACC DMEM, start the ACC via a designated CSR, and on ACC completion fetch the results from ACC DMEM.
There are some small additional steps taken on the primary processor for defense-in-depth, but the cryptolib implementations for ACC-backed operations still lie almost entirely in the ACC programs used; this is correspondingly where virtually all SCA mitigations take place.

ACC PQC performance: Careful attention has been paid in particular to the vectorized ISA extensions used in the ACC ML-KEM and ML-DSA implementations.
For a detailed analysis of how the ISA extensions have been designed in a performant and area-conscious way, see the initial *Towards ML-KEM & ML-DSA on Opentitan* ([https://eprint.iacr.org/2024/1192](https://eprint.iacr.org/2024/1192)) and subsequent *Improving ML-KEM and ML-DSA on OpenTitan* ([https://eprint.iacr.org/2025/2028](https://eprint.iacr.org/2025/2028)) papers.

## Scope: Attack Methods

Timing attacks: As part of our analysis regarding side-channel attacks, we include all manner of timing attacks, including cache timing attacks, to be within scope.

Passive physical attacks: We further consider power and electromagnetic side-channels to be in scope.

Active physical attacks: Differential faulting attacks as a form of side-channel analysis are also included in scope, but for protecting against fault-injection attacks in general, we strongly recommend dual-core lockstep configurations of the ACC to be used.
More defense-in-depth approaches are discussed below.

Operations considered: All security assets used or generated in the course of key generation, encryption/decryption, signing/verification, or key encapsulation/decapsulation are considered within scope for these attacks.

Profiled vs. non-profiled attacks: In the following, we implicitly combine discussion of profiled (e.g. CPA) and non-profiled (e.g. SPA) side-channel attacks, as e.g. for operations like keygen, we may want to assume that an attacker has some limited ability to, say, replay entropy through an operation.
Moreover, the protections at the hardware level against both types of attacks are the same, and generally speaking the same primitive operations are usually involved in other repeatable operations as in keygen.

## Scope: Security Assets

Private keys: In this analysis, we consider all private keys stored in the ACC, including those derived as a result of an operation (e.g. the resulting keys from keygen operations, or KEM encapsulation/decapsulation) security assets which must be protected from an attacker employing the above methods.

User-provided secret values: Other user-provided secret values, such as plaintexts for encryption, are similarly designated as security assets.

Intermediate results: Additionally, any intermediate value computed by the ACC which could reveal a non-negligible amount of information about one of the above security assets must also be treated as a security asset.

## Mitigations: Overall

Timing side-channel mitigations: To address timing side-channels, ACC programs can be statically analyzed using a purpose-built tool to construct their control flow graph and ensure that no branches (aside from e.g. signature rejection loopback in ML-DSA) depend on secret values.
These checks as currently performed are done as recurring tests in CI, preventing accidental introduction of timing side-channels after changes to an ACC program.

Additionally, all ACC instructions take the same number of cycles regardless of ACC state.
In particular, ACC branch instructions are implemented to take the same number of cycles regardless of whether the branch is taken or not; this fact is also used to prevent Spectre-style speculative execution attacks on the ACC.
To allow fast conditionals, a single-cycle WDR ‘select’ instruction is used.
See [*From Artifact to Production: Integrating and Refining Lattice Cryptography Acceleration*](https://www.zerorisc.com/blog/from-artifact-to-production-integrating-and-refining-lattice-cryptography-acceleration) for an in-depth example of optimizing ML-KEM rejection sampling using this approach.

Passive side-channel mitigations: Standard mitigations such as first-order masking and blinding have been used extensively throughout e.g. the P-256 and P-384 implementations.
Prior analysis using CocoAlma on SCA traces from FPGA builds has been used to determine the set of cases where shares may interact in the ACC datapath, including motifs which cause transient leakage, and in turn care has been taken to avoid and eliminate these constructions in the code.

Active side-channel mitigations: As noted above, a dual-core lockstep ACC implementation is the primary recommended approach for mitigating active attacks.
This said, there are several defense-in-depth mechanisms also employed, including PRINCE scrambling for ACC memories, running hardware checksums for DMEM writes, and hardened runtime comparisons of ACC instruction counts to statically-determined runtime bounds.

## Proposed Empirical SCA Methodology

Planned methodology: for initial assessment and ongoing evaluation of side-channel leakage, standard TVLA methodology (fixed vs. random Welch’s t-test) will be used with a ChipWhisperer CW340 FPGA board as target, testing isolated routines (e.g. for ML-KEM, this would include pointwise multiplication, NTT/INTT, message decoding, etc.) as well as full instantiations of algorithms, e.g. a plaintext-checking oracle.
More extensive follow-up analyses will be performed using detailed manual inspection of traces, including evaluation of state-of-the-art techniques from the literature.
