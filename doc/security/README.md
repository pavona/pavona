# Security

A fundamental part of Pavona's quality lies in the trustworthy nature of its hardware security-related assets.

Both the Earlgrey and Darjeeling top levels are hardware root-of-trust (RoT) systems which adhere to these standards and utilize the security resources within Pavona.

## Specifications and Standards

### [Earlgrey Security Model Specification][security_model]

The [Earlgrey Security Model Specification][security_model] defines the logical security properties of Earlgrey, a discrete IC RoT.
It covers device and software attestation, provisioning, secure boot, chip lifecycle, firmware update, chip identity, and chip ownership transfer.

### [Logical Security Model][logical_security_model]

A [Logical Security Model][logical_security_model] provides a high level framework for device provisioning and run-time operations.
It starts by enumerating the range of logical entities supported by the architecture, and their mapping into software stages.
Runtime isolation properties and baseline identity concepts are introduced in this document.

### [Secure Hardware Design Guidelines][implementation_guidelines]

Silicon designs for security devices require special guidelines to protect the designs against myriad attacks.
To that end, the [Secure Hardware Design Guidelines][implementation_guidelines] provide guidance for developing security IP.

### [Lightweight Threat Model][threat_model]

The [Lightweight Threat Model][threat_model] delineates the anticipated design assets, attacker profiles, attack methods, and attack surfaces for Earlgrey and Darjeeling.

## Security Primitives

All hardware security primitives adhere to the [comportable][comportable_ip] peripheral interface specification.
Implementations for some of these components are available for reference and may not meet production or certification criteria yet.

### [Entropy source][entropy_source]

Digital wrapper for a NIST SP 800-90B compliant entropy source.
An additional emulated entropy source implementation will be available for FPGA functional testing.

### [CSRNG][csrng]

Cryptographically Secure Random Number Generator (CSRNG) providing support for both deterministic (DRBG) and true random number generation (TRNG).

The DRBG is implemented using the `CTR_DRBG` construction specified in NIST SP 800-90A.

### [AES][aes]

Advanced Encryption Standard (AES) supporting Encryption/Decryption using 128/192/256 bit key sizes in the following cipher block modes:

*   Electronic Codebook (ECB) mode,
*   Cipher Block Chaining (CBC) mode,
*   Cipher Feedback (CFB) mode with fixed data segment size of 128 bits,
*   Output Feedback (OFB) mode, and
*   Counter (CTR) mode.

Galois/Counter Mode (GCM) can be implemented by leveraging Ibex for the GHASH operation as demonstrated in the [library of cryptographic implementations][cryptolib].

### [HMAC][hmac]

HMAC with SHA-2 FIPS 180-4 compliant hash function, supporting both HMAC-SHA256 and SHA256 modes of operation.

### [Key Manager][keymgr]

Hardware backed symmetric key generation and storage providing key isolation from software.

### [Asymmetric Cryptographic Coprocessor (ACC)][acc]

Public key algorithm accelerator with support for bignum operations in hardware.

### [Alert Handler][alert_handler]

Aggregates alert signals from other system components designated as potential security threats, converting them to processor interrupts.
It also supports alert policy assignments to handle alerts completely in hardware depending on the assigned severity.

## Using Earlgrey and Darjeeling

At the functional level, these top level RoTs should:

*   Enable RoT Public Key Infrastructure (PKI) to Silicon Owners who have taken ownership of the device.
*   Have their hardware's authenticity endorsed by Silicon Creators.
    Endorsement is contingent on the silicon adhering to the physical implementation guidelines and standard requirements stipulated by the project.
    The endorsement shall be measurable via a Transport Certificate.
*   Provide full boot attestation measurements to allow Silicon Owners to verify the boot chain configuration.
    The attestation chain shall be anchored in the Silicon Owner's RoT PKI.
*   Provide a key manager implementation strongly bound to the boot chain.
    Only a boot chain signed with the expected set of keys shall be able to unlock stored keys/secrets.
*   Provide a key versioning scheme with support for key migration bound to the firmware versioning and update implementation.


[aes]: ../../hw/ip/aes/README.md
[alert_handler]: ../../hw/top_earlgrey/ip_autogen/alert_handler/README.md
[comportable_ip]: ../contributing/hw/comportability/README.md
[csrng]: ../../hw/ip/csrng/README.md
[entropy_source]: ../../hw/ip/entropy_src/README.md
[hmac]: ../../hw/ip/hmac/README.md
[keymgr]: ../../hw/ip/keymgr/README.md
[logical_security_model]: ./logical_security_model/README.md
[implementation_guidelines]: ./implementation_guidelines/hardware/README.md
[acc]: ../../hw/ip/acc/README.md
[security_model]: ./specs/README.md
[threat_model]: ./threat_model/README.md
[cryptolib]: ../../sw/device/lib/crypto
