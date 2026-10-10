# ACVP

[ACVP](https://pages.nist.gov/ACVP/) is the protocol NIST's Cryptographic Algorithm Validation Program (CAVP) uses to validate a cryptographic implementation, which is a prerequisite for a FIPS 140-3 certificate.
A module registers the capabilities it claims, the validation server generates a vector set for each algorithm and mode from that registration, and the module answers every test case in them.
The server checks the answers against its own and issues the validation.

An accredited testing laboratory runs the session on the vendor's behalf.
It registers the capabilities, hands over the vector sets it downloads, and submits the responses it gets back.
A session therefore arrives as one vector set per algorithm and mode, each needing a response in return.

We aim to make answering those vector sets as close to a single command as we can.
The registration below records what the cryptolib claims, and [`util/acvp_client.py`](/util/acvp_client.py) runs a session's vector sets on the device and produces the responses to submit.

`registration/` documents the ACVP capabilities supported by the cryptolib ACVP harness, one file per algorithm and mode.
Each file is a self-contained JSON object in the format defined by the [ACVP specification](https://pages.nist.gov/ACVP/).

These are ACVP testing capabilities, which may be narrower than the cryptolib capabilities.

## Supported algorithms

- [AES-KWP](https://pages.nist.gov/ACVP/draft-celi-acvp-symmetric.html): encrypt, decrypt.
- [ML-DSA](https://pages.nist.gov/ACVP/draft-celi-acvp-ml-dsa.html): keyGen, sigGen, sigVer.
- [ML-KEM](https://pages.nist.gov/ACVP/draft-celi-acvp-ml-kem.html): keyGen, encapDecap.

## Unsupported capabilities

### AES-KWP

- `kwCipher: inverse`.
  The cryptolib wraps with the AES encryption direction only.
- Payloads of at most 64 bits.
  The cryptolib does not implement the single-block case.
- AES-KW, the variant without padding.

### ML-DSA

- `externalMu: false` on the internal signature interface, where ACVP distinguishes a caller-supplied mu (`true`) from one the module derives from a raw message (`false`).
  The module implements only the former; the external interface is unaffected.
- HashML-DSA with SHA2-224, SHA2-512/224 or SHA2-512/256.
  Those hash functions are not implemented.
- The `FIPS204-tr1` revision of sigGen, which adds a `keyFormats` capability.

### ML-KEM

- `encapsulationKeyCheck` and `decapsulationKeyCheck`.
  The cryptolib exposes no public key validation API.
  The pinned vector sets still run these groups as regression tests, mapped onto encapsulation and decapsulation, whose internal checks reject invalid keys.
- The `FIPS203-tr1` revision of encapDecap, which adds a `keyFormats` capability.

## Running sample vector sets

A vector set is answered the same way whether it comes from a certification session or from the pinned test data: the prompt goes in, and a response comes out.
The parsers turn a prompt into the inputs the harness sends to the device, and the harness assembles the device's outputs into a response.

The pinned vector sets run as part of the AES-KWP, ML-DSA and ML-KEM known-answer tests:

```sh
./bazelisk.sh test //sw/device/tests/crypto/cryptotest:aes_kwp_kat_fpga_cw340_test_rom
./bazelisk.sh test --define=acc_has_pqc=true //sw/device/tests/crypto/cryptotest:mldsa_kat_fpga_cw340_pqc_test_rom
./bazelisk.sh test --define=acc_has_pqc=true //sw/device/tests/crypto/cryptotest:mlkem_kat_fpga_cw340_pqc_test_rom
```

These compare the assembled response against the expected results NIST publishes alongside each prompt.
For ML-DSA and ML-KEM, `--define=acc_has_pqc=true` selects the ACC backends; without it, the same targets test the software backends instead.
The `_hardened` variants of the ML-DSA and ML-KEM targets always test the hardened ACC backend.

### Running your own ACVP test vectors

For running your own vector sets (e.g., during certification) [`util/acvp_client.py`](/util/acvp_client.py) can be used.
It converts ACVP prompts into test vector files and runs them through the cryptolib implementations.
Optionally, expected results can be passed (e.g., during testing).

Sample usage:

```sh
./bazelisk.sh run //util:acvp_client -- my_test_vectors/*/testvector-request.json \
    --expected my_test_vectors/*/testvector-expected.json \
    --out responses/
```

Responses are written to the directory passed to `--out`. Without it they land in the test's undeclared outputs, under `bazel-testlogs`.
The ACC backends are built into the firmware by default; `--no-acc-pqc` tests the software backends instead.
`--hardened` selects the hardened ACC backend, and `--exec-env` a different execution environment.
`--test-arg` forwards an argument to the test itself, such as `--test-arg=--usb-serial=<serial>` to pick between attached boards.

The parser rejects any test case this cryptolib cannot answer.
Pass `--skip-unsupported` to tolerate and skip unsupported vectors, e.g., when testing against NIST's samples which cover every capability.
