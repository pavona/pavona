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

Some ACVP test cases are deferred.
Their prompt leaves some values open for the implementation to choose, and the response returns the chosen values together with the answer.
The server computes its own answer from those values once it receives the response.

The expected results of a sample vector set only hold for the values NIST chose.
To test deferred test cases against known answers, the pinned vector sets use those values, taken with the expected results from the sample's `internalProjection.json`.
For a prompt from a certification session, we choose the open values, and only the server can check the response.
The supported algorithms below mark those with deferred test cases.

## Supported algorithms

- [AES-CBC, AES-CFB128, AES-ECB, AES-OFB](https://pages.nist.gov/ACVP/draft-celi-acvp-symmetric.html): AFT, MCT.
- [AES-KWP](https://pages.nist.gov/ACVP/draft-celi-acvp-symmetric.html): encrypt, decrypt.
- [HMAC-SHA2-256, HMAC-SHA2-384, HMAC-SHA2-512](https://pages.nist.gov/ACVP/draft-fussell-acvp-mac.html): AFT, revision 2.0.
- [KDA HKDF](https://pages.nist.gov/ACVP/draft-hammett-acvp-kas-kdf-hkdf.html) with SHA2-256, SHA2-384 and SHA2-512: AFT, VAL, revision Sp800-56Cr2.
- [KDF](https://pages.nist.gov/ACVP/draft-celi-acvp-kbkdf.html) with HMAC-SHA2-256, HMAC-SHA2-384 and HMAC-SHA2-512: counter and feedback mode, AFT (deferred), revision 1.0.
- [KDF KMAC](https://pages.nist.gov/ACVP/draft-celi-acvp-kbkdf.html) with KMAC-128 and KMAC-256: AFT, revision Sp800-108r1.
- [ML-DSA](https://pages.nist.gov/ACVP/draft-celi-acvp-ml-dsa.html): keyGen, sigGen, sigVer.
- [ML-KEM](https://pages.nist.gov/ACVP/draft-celi-acvp-ml-kem.html): keyGen, encapDecap.
- [SHA2-256, SHA2-384, SHA2-512](https://pages.nist.gov/ACVP/draft-celi-acvp-sha.html): AFT, MCT.
- [SHA3-224, SHA3-256, SHA3-384, SHA3-512](https://pages.nist.gov/ACVP/draft-celi-acvp-sha3.html): AFT, MCT.
- [SHAKE-128, SHAKE-256](https://pages.nist.gov/ACVP/draft-celi-acvp-sha3.html): AFT, revision FIPS202.

## Unsupported capabilities

### AES-CBC, AES-CFB128, AES-ECB, AES-OFB

- AES-CFB1 and AES-CFB8.
  The cryptolib implements CFB with 128-bit segments only.

The device runs the whole Monte Carlo test.

### AES-KWP

- `kwCipher: inverse`.
  The cryptolib wraps with the AES encryption direction only.
- Payloads of at most 64 bits.
  The cryptolib does not implement the single-block case.
- AES-KW, the variant without padding.

### HMAC

- Revision 1.0, which cannot restrict the message length.
- HMAC-SHA-1, HMAC-SHA2-224, HMAC-SHA2-512/224, HMAC-SHA2-512/256 and HMAC-SHA3.
  The cryptolib does not implement them.
- MACs shorter than the digest.
  The cryptolib returns the whole MAC.
  The pinned sample vector sets ask for truncated MACs, so the harness truncates the device's MAC for prompts that come with expected results.
- Keys longer than 512 bytes.
  The cryptolib limits HMAC keys to `kOtcryptoHmacMaxKeyBytes`.
- Messages longer than 512 bytes.
  The harness limits HMAC messages to `HMAC_CMD_MAX_MESSAGE_BYTES`.

### KDA HKDF

- FixedInfo patterns other than `uPartyInfo||vPartyInfo||l`, and encodings other than concatenation.
  The parser assembles FixedInfo and passes it to `otcrypto_hkdf` as `info`, as the ACVP harnesses of AWS-LC and BoringSSL do.
- Hybrid shared secrets and multi-expansion tests.
- HMAC with hash functions other than SHA2-256, SHA2-384 and SHA2-512.
  The cryptolib does not implement them.

The pinned vector set is the Sp800-56Cr1 sample, because every group of the Sp800-56Cr2 sample uses a hybrid shared secret.
The two revisions derive keys the same way.

### KDF (SP 800-108)

- Counters other than 32 bits before the fixed data in counter mode, and other than 8 bits after the fixed data in feedback mode.
  The cryptolib fixes the length and position of the counter.
- Feedback mode with an IV, and key derivation keys other than the hash length in feedback mode.
  Feedback mode is `otcrypto_hkdf_expand`, which starts from an empty IV and takes a pseudorandom key of the hash length.
- Double-pipeline iteration mode, and CMAC as the PRF.
- HMAC with hash functions other than SHA2-256, SHA2-384 and SHA2-512.
  The cryptolib does not implement them.
- Output lengths that are not a whole number of bytes.
  The cryptolib derives bytes.

The parser chooses the fixed data.

### KDF KMAC (SP 800-108r1)

- Key derivation keys other than 256, 384 and 512 bits.
  The cryptolib supports keys of 128, 192, 256, 384 and 512 bits for KMAC-128, and of 256, 384 and 512 bits for KMAC-256.
  A registration has one list of key lengths, which applies to both KMAC-128 and KMAC-256.
- Labels longer than 32 bytes.
  The KMAC hardware does not support them.
- Derived key lengths that are not a multiple of 32 bits.
  The cryptolib derives whole 32-bit words.

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

### SHA2 and SHA3

- SHA2-224, SHA2-512/224 and SHA2-512/256.
  The cryptolib does not implement them.
- Messages that are not a whole number of bytes.
  The cryptolib hashes bytes.
- The large data test (`performLargeDataTest`).
  The cryptolib has no streaming SHA3 API, and the cryptotest does not stream SHA2 messages.

The device runs the whole Monte Carlo test, all 100 outer and 1000 inner iterations.

### SHAKE

- Revision 1.0, with its bit-oriented messages, Monte Carlo and variable output tests.
- Messages that are not a whole number of bytes.
- Output lengths that are not a whole number of 32-bit words.
  The cryptolib returns whole words.

## Running sample vector sets

A vector set is answered the same way whether it comes from a certification session or from the pinned test data: the prompt goes in, and a response comes out.
The parsers turn a prompt into the inputs the harness sends to the device, and the harness assembles the device's outputs into a response.

The pinned vector sets run as part of the AES-KWP, HKDF, HMAC, KDF, ML-DSA, ML-KEM, SHA2, SHA3 and SHAKE known-answer tests:

```sh
./bazelisk.sh test //sw/device/tests/crypto/cryptotest:aes_kwp_kat_fpga_cw340_test_rom
./bazelisk.sh test --define=acc_has_pqc=true //sw/device/tests/crypto/cryptotest:mldsa_kat_fpga_cw340_pqc_test_rom
./bazelisk.sh test --define=acc_has_pqc=true //sw/device/tests/crypto/cryptotest:mlkem_kat_fpga_cw340_pqc_test_rom
./bazelisk.sh test //sw/device/tests/crypto/cryptotest:sha3_256_kat_fpga_cw340_test_rom
```

The `hkdf_kat` target covers KDA HKDF, the `kdf_hmac_kat` target covers KDF, and the `hmac_sha256_kat`, `hmac_sha384_kat` and `hmac_sha512_kat` targets cover HMAC.
The `sha256_kat`, `sha384_kat`, `sha512_kat`, `sha3_224_kat`, `sha3_384_kat`, `sha3_512_kat`, `shake128_kat` and `shake256_kat` targets cover the other SHA2, SHA3 and SHAKE variants.

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

## Generating test vectors

NIST's sample vector sets are generated from sample registrations, which sometimes cover capabilities the cryptolib does not implement.
In such cases, it can make sense to generate our own test vectors that match the capabilities of the cryptolib exactly.
This can be done with the [registration files](registration/) in this repository and NIST's [ACVP-Server](https://github.com/usnistgov/ACVP-Server).

To generate test vectors, we provide a [genval container](/util/acvp/genval/Dockerfile).
It can be built with:

```sh
docker build -t acvp-genval util/acvp/genval
```

It provides two main functions:

- `genval check` checks a registration file.
- `genval vectors` generates a vector set from a registration file.

For example, to generate test vectors for a registration, run:

```sh
docker run --rm --user $(id -u):$(id -g) -v $PWD:/work acvp-genval \
    vectors /work/sw/host/cryptotest/testvectors/acvp/registration/<registration>.json /work/acvp-vectors
```

It writes the set to `acvp-vectors/<version>/<algorithm>/<registration hash>/`, where the hash is the SHA-256 of the registration file.

We host the generated test vectors in a [public bucket](https://storage.googleapis.com/pavona-test-vectors).
