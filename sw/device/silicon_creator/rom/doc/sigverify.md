# ROM Signature Verification Module

This document describes the signature verification module (sigverify) which is responsible for verifying the authenticity and integrity of boot stages after the metal ROM.
The Pavona reference firmware supports hybrid ECDSA-P256 and ML-DSA-87 signature verification.

## Signature Verification

Signature verification consists of four main steps:

1. Get the public key to verify the signature of an image.
1. Compute the digest of the image.
1. Perform signature verification to generate the encoded message.
1. Check the encoded message.

## Public Keys

[Firmware manifests][firmware-mainfests] for each boot stage contain the public key for verifying their signatures.
While this information is useful for checking the integrity of an image off-target, e.g. using a developer utility, it's trivial for an attacker to sign an image with an arbitrary key.
In order to establish the authenticity of a manifest, the sigverify module uses authorized public keys stored in flash [key manifests][key-manifests] for signature verification.
The Silicon Creator key manifest is verified using a ladder of additional public keys stored in metal ROM and OTP.
Later boot roles' key manifests are verified using a public key stored in the [ownership block][ownership-block] for that role.
See [Root Keys][root-keys] documentation for more details how the keys are configured and provisioned.

## Digest Computation

Sigverify uses SHA-384 for digest computation.
The signed region of a firmware image starts immediately after the signature field of its manifest, i.e. its first field, and extends to the end of the image.
While signing an image, the digest of its signed area is computed as usual.
During verification in ROM, sigverify reads usage constraints from the device (instead of using the values in the manifest directly) and uses these values for computing the digest for signature verification:

```
digest = SHA256(usage_constraints_from_hw || rest_of_the_image).
```

The advantage of this approach is that it does not require any changes in signature generation or off-target signature verification.
See the usage constraints fields (`selector_bits`, `device_id`, `manuf_state_creator`, `manuf_state_owner`, `life_cycle_state`) in [manifest documentation](../../rom_ext/doc/manifest.md) for more details.

<!-- References -->
[firmware-manifests]: ../../rom_ext/manifest.md
[key-manifests]: ../../../../../doc/security/specs/secure_boot/README.md#key-manifests
[ownership-block]: ../../../../../doc/security/specs/ownership_transfer/README.md
[root-keys]: ./root_keys.md
