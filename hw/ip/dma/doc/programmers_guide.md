# Programmer's Guide

This section details how software can interface with the Direct Memory Access (DMA) controller.

## Module Initialization

Before initiating memory transfers using the DMA for internal memory, software must define the accessible memory range for the DMA.
This involves a specific sequence of register writes:

1.  **Define the Memory Range:** First, software must write the base address to the [`ENABLED_MEMORY_RANGE_BASE`](registers.md#enabled_memory_range_base) register and the upper limit of the accessible range to the [`ENABLED_MEMORY_RANGE_LIMIT`](registers.md#enabled_memory_range_limit) register.
2.  **Validate the Range:** Next, to indicate that the configured range contains valid data, software must write to the [`RANGE_VALID`](registers.md#range_valid) register.
3.  **Optional Range Locking:** Optionally, software can write to the [`RANGE_REGWEN`](registers.md#range_regwEN) register to lock the configured memory range. Once locked, the range configuration cannot be modified until the next reset of the DMA.

## Initiate a Memory transfer

To start a memory transfer, software needs to configure several registers that define the source and destination of the data, as well as the transfer size and access pattern:

1.  **Source and Destination Configuration:** Configure the source and destination address modes using the [`SRC_CONFIG`](registers.md#src_config) and [`DST_CONFIG`](registers.md#dst_config) registers. The DMA supports 3 addressing modes, which can be configured independently for the source and destination via the aforementioned registers:
  * Continuously accessing the same address (`increment = 0`, `wrap = 1`)
  * Linear addressing (`increment = 1`, `wrap = 0`), with an address increment after each transfer
  * Wrap Mode:  (`increment = 1`, `wrap = 1`), with an address increment after each transfer and a wrap to the start address after finishing the transfer of one chunk.
2.  **Source and Destination Addresses:** Specify the starting memory addresses for the source and destination using the lower and upper 32-bit parts of the addresses in the [`SRC_ADDR_LO`](registers.md#src_addr_lo), [`SRC_ADDR_HI`](registers.md#src_addr_hi), [`DST_ADDR_LO`](registers.md#dst_addr_lo), and [`DST_ADDR_HI`](registers.md#dst_addr_hi) registers.
3.  **Total Transfer Size:** Define the total number of bytes to be transferred using the [`TOTAL_DATA_SIZE`](registers.md#total_data_size) register.
4.  **Access Stride:** Configure the access stride (the number of bytes accessed in each burst) using the [`TRANSFER_WIDTH`](registers.md#transfer_width) register.
5.  **Chunk Size (Memory-to-Memory):** The DMA performs memory access in chunks. For a standard memory-to-memory transfer, the [`CHUNK_DATA_SIZE`](registers.md#chunk_data_size) register is typically set to the same value as the [`TOTAL_DATA_SIZE`](registers.md#total_data_size) register. The concept of chunked transfers is further explained in the [Chunked Data Transfers](#Chunked_Data_Transfers) section.
6.  **Start the Transfer:** Initiate the transfer by writing to the `go` bit along with the `initial_transfer` bit in the [`CONTROL`](registers.md#control) register.
7.  **Monitor Transfer Completion:** After starting the transfer, software can monitor its progress by either polling the [`STATUS`](registers.md#status) register or by waiting for a specific interrupt to be raised.

### Interrupt Handling

The DMA can signal various events to the software through interrupts.
The following three types of interrupts are supported:

1.  **Transfer Completion:** An interrupt is raised when the entire data transfer (as defined by `TOTAL_DATA_SIZE`) is complete.
2.  **Chunk Completion:** An interrupt is raised after the transfer of a single chunk of data (as defined by `CHUNK_DATA_SIZE`) is finished. This interrupt is only available when not using the [Hardware Handshaking Mode](#Hardware_Handshaking_Mode).
3.  **Error Condition:** An interrupt is raised if an [error](#Error Condition) occurs during the transfer process.

The current status of the DMA, including pending interrupts, can be read from the [`STATUS`](registers.md#status) register.
Since interrupts are implemented as status bits, they are cleared by writing a '1' to the corresponding bit in the `STATUS` register.

### Aborting a Transfer

Software can terminate an ongoing DMA transfer at any point by writing to the `abort` bit in the [`CONTROL`](registers.md#control) register.
Aborting an operation happens immediately after writing the `abort` bit and does not require any further scheduling or waiting.
The [`STATUS`](registers.md#status) indicates via the `aborted` bit that the DMA operation was aborted and the DMA stopped its operation.

## Chunked Data Transfers

The DMA performs memory transfers in discrete units called chunks.
Each chunk consists of a contiguous block of data with a size defined by the [`CHUNK_DATA_SIZE`](registers.md#chunk_data_size) register.
After transferring a chunk, the DMA can optionally generate an interrupt.

While chunked transfers are primarily utilized in conjunction with the [Hardware Handshaking Mode](#Hardware_Handshaking_Mode) for interacting with IO peripherals, they can also be employed in memory-to-memory transfers.
A potential use case for chunked memory-to-memory transfers is memory initialization, where a small chunk of data (e.g., a block of zeros) can be repeatedly transferred to a larger memory region.
For chunked data transfers the first transfer needs to assert the `initial_transfer` bit in the [`CONTROL`](registers.md#control) register.
Initiating the transfer of subsequent chunks must not assert the `initial_transfer` bit.

## Hardware Handshaking Mode

The DMA supports a hardware handshaking mode that enables seamless data transfers between IO peripherals and memory.
This mode leverages the chunked data transfer mechanism and interrupts from the IO peripheral.

In this mode, the IO peripheral fills its internal transfer FIFO and then signals the DMA by raising an input line that acts like a 'Status' type hardware interrupt.
Upon receiving this signal, the DMA reads the data from the peripheral's FIFO and writes it to the destination memory.
This process continues in a loop: the DMA transfers a chunk of data, waits for the IO peripheral to repopulate its FIFO and issue another interrupt, and then transfers the next chunk.
This loop repeats until the total number of bytes specified by [`TOTAL_DATA_SIZE`](registers.md#total_data_size) has been transferred.

To enable hardware handshaking, software must set the `hardware_handshake_enable` bit in the [`CONTROL`](registers.md#control) register and configure the appropriate addressing mode to access the IO peripheral.

The DMA's chunked transfer mechanism in hardware handshaking mode supports two address update modes for the peripheral:

  * **Fixed address:** The DMA accesses the same address for each chunk.
  * **Wrap-around:** After transferring a chunk, the DMA's peripheral address wraps around to the starting address configured for the transfer.

These modes are configured via the [`SRC_CONFIG`](registers.md#src_config) and [`DST_CONFIG`](registers.md#dst_config) registers as described above.
For interrupt handling in hardware handshaking mode, software needs to enable the corresponding interrupt using the [`HANDSHAKE_INTR_ENABLE`](registers.md#handshake_intr_enable) register.

The DMA also provides a mechanism to acknowledge the interrupt received from the IO peripheral by performing a configurable write operation.
If interrupt acknowledgement is required, software must enable it in the [`CLEAR_INTR_SRC`](registers.md#clear_intr_src) register.
Each interrupt source selects its target port through its `CLEAR_INTR_ASID` register.
Program the encoded ASID of any configured port before enabling that source's clearing write.
An invalid or unconfigured target raises `ERROR_CODE.asid_error` without issuing that write.
The specific address and data value to be written for acknowledgement are defined by the [`INTR_SRC_ADDR_0-10`](registers.md#intr_src_addr) and [`INTR_SRC_WR_VAL_0-10`](registers.md#intr_src_wr_val) registers, respectively.

## Selecting the Operation

### Address-space identifiers

`ADDR_SPACE_ID.src_asid` occupies bits 7:0 and `dst_asid` occupies bits 15:8.
ASIDs identify ports independently of their positions in `PortDesc`. The 16 supported
encodings are `03`, `0c`, `30`, `3f`, `56`, `59`, `65`, `6a`, `95`, `9a`, `a6`, `a9`,
`c0`, `cf`, `f3`, and `fc` (hexadecimal). Their minimum Hamming distance is four;
zero and all-ones are invalid. Only IDs assigned in `PortDesc` are accepted.
Unassigned codewords are reserved for future ports, not aliases of existing ports.

The default integration assigns `03` to internal memory, `0c` to the control network,
and `30` to the system port. Firmware must use the generated register constants;
the old 4-bit encodings and interrupt-clear bus bitmap are not compatible.
`CLEAR_INTR_ASID` provides one 32-bit register per interrupt source, with its ASID
in bits 7:0. These registers reset to zero, requiring explicit configuration for
enabled clearing writes. Disabled clearing sources do not require a valid ASID.

### Operation fields

The type of operation performed by the DMA is selected by three orthogonal fields in the [`CONTROL`](registers.md#control) register:

  * `read_en`: when set, the DMA reads from the source memory. When cleared, no source read is performed and the write data is instead taken from the pattern programmed in the [`SRC_ADDR_LO`](registers.md#src_addr_lo) register.
  * `write_en`: when set, the DMA writes to the destination memory. When cleared, no write is performed.
  * `digest`: selects the inline SHA-2 digest computed over the moved data (`NONE`, `SHA256`, `SHA384`, or `SHA512`).

Combining these fields yields the following operations:

  * **Copy:** Set `read_en = 1`, `write_en = 1`, and `digest = NONE`. The DMA reads data from the source and writes it to the destination.
  * **Copy + Hash:** Set `read_en = 1`, `write_en = 1`, and `digest` to the desired SHA-2 algorithm. The DMA reads data from the source, writes it to the destination, and concurrently computes the hash digest of the transferred data (see [Inline Hashing](#inline-hashing)).
  * **Memset:** Set `read_en = 0`, `write_en = 1`, and `digest = NONE`. No source read is performed; instead the DMA fills the destination with the pattern programmed in [`SRC_ADDR_LO`](registers.md#src_addr_lo). For sub-word transfer widths (1 or 2 bytes) the pattern is replicated across the bus word in little-endian order, keyed on the destination address.
  * **Verify:** Set `read_en = 1`, `write_en = 0`, and `digest` to the desired SHA-2 algorithm. The DMA reads a memory region and computes its digest without writing to any destination, which is useful for integrity or attestation checks. Software reads the result from the [`SHA2_DIGEST_0-15`](registers.md#sha2_digest) registers.

The DMA rejects illegal field combinations (for example a no-op with no read and no write, hashing without a read, reading and discarding data without computing a digest, or a hardware handshake with neither read nor write enabled). Such a configuration is reported via the error bit in the [`ERROR_CODE`](registers.md#error_code) register.

## Inline Hashing

The DMA incorporates an inline hashing capability for SHA-2 algorithms (SHA-256, SHA-384, and SHA-512).
This allows the DMA to compute the hash digest of the transferred data concurrently with performing the memory transfer.

To enable inline hashing, software must select the desired SHA-2 algorithm in the `digest` field of the [`CONTROL`](registers.md#control) register.
This instructs the DMA to compute the hash digest of the data being moved.

When initiating a transfer with inline hashing, the `initial_transfer` bit in the [`CONTROL`](registers.md#control) register must be asserted.
This signals the DMA to initialize its internal hash state.
When using chunked transfers with inline hashing, subsequent chunk transfers should have the `initial_transfer` bit cleared to prevent re-initialization of the hash state between chunks.

Once the transfer is complete, the computed hash digest value can be read from the [`SHA2_DIGEST_0-15`](registers.md#sha2_digest) registers.

The endianness of the resulting hash digest can be configured using the `digest_swap` bit in the [`CONTROL`](registers.md#control) register.
Changing this bit affects the digests of subsequent DMA transfers; it does not alter the current contents of the [`SHA2_DIGEST_0-15`](registers.md#sha2_digest) registers.

## Inline AES Encryption

The DMA can encrypt or decrypt the moved data on-the-fly using AES-CTR or AES-GCM (see [Theory of Operation](theory_of_operation.md#inline-aes-encryption)).
To program an inline AES transfer:

1. Provide the key: write the two shares to [`KEY_SHARE0`](registers.md#key_share0)/[`KEY_SHARE1`](registers.md#key_share1) (their XOR is the key), or set [`AES_CTRL.sideload`](registers.md#aes_ctrl--sideload) to use the key-manager key.
2. Set [`AES_CTRL.key_len`](registers.md#aes_ctrl--key_len) and, for GCM with associated data, write the [`AAD`](registers.md#aad) registers and [`AES_CTRL.aad_blocks`](registers.md#aes_ctrl--aad_blocks).
3. Write the 96-bit nonce to [`IV`](registers.md#iv)`[3:1]` (the counter word `IV[0]` is hardware-managed).
4. For a GCM decrypt, write the expected authentication tag to [`TAG_IN`](registers.md#tag_in).
5. Configure the transfer as usual (source/destination addresses, sizes, 4-byte transfer width) and select the operation in [`CONTROL`](registers.md#control): `aes_op` = `Enc`/`Dec` and `aes_mode` = `CTR`/`GCM`, with `digest` = `None`. Assert `initial_transfer`.
6. Start the transfer with `go`.

The transfer must use a 4-byte transfer width and nonzero total/chunk sizes that are multiples
of 16 bytes. Source and destination independently support the normal DMA addressing modes:
`increment = 0` accesses one fixed FIFO register on every beat; `increment = 1` advances by
four bytes per beat. With `wrap = 1`, an incrementing endpoint returns to its programmed base
at each chunk boundary. With `wrap = 0`, it continues into the next memory region.
Fixed-address endpoints keep their base address regardless of `wrap`.
The sizes may differ: a shorter final chunk transfers only the remaining bytes, and a chunk
size greater than the total completes in one chunk.

In software-paced mode, at an intermediate chunk boundary, `chunk_done` is asserted and `go` and `busy` are cleared.
Resume by setting `go` with `initial_transfer = 0`. The key, counter, and GHASH state remain
live, and `CFG_REGWEN` remains locked, including the AES configuration, addresses, and sizes.
Hardware advances non-wrapping, incrementing addresses by the bytes moved in each chunk.
Fixed or wrapping endpoints keep their programmed base. AAD is processed once, and
the GCM tag is generated or checked only after the entire message. To replace a suspended
message, first abort it and wait for `aborted` and an unlocked `CFG_REGWEN` before reprogramming.
Starting a new initial transfer while a message is suspended raises an opcode error and wipes
the retained AES state. GCM supports at most 8191 text blocks (131056 bytes) per message.

For hardware pacing, configure `HANDSHAKE_INTR_ENABLE` and the optional interrupt-clear
writes, then set `hardware_handshake_enable` along with the initial `go`. Each chunk starts
when an enabled trigger is high. Arming a new initial transfer clears the previous message's
`tag_valid` and `tag_failed`, even while waiting for the first trigger.
Between chunks, `go`, `busy`, the cipher state and the
configuration lock remain set; `chunk_done` is not raised and no software restart is needed.
A trigger held high allows the next chunk to start immediately. The trigger source must
withdraw it (or be cleared by the configured interrupt-clear write) to pause the transfer.
These triggers authorize an entire chunk, not individual bus beats. An input device must
provide that many source bytes and an output device must reserve that much destination space
before triggering. For the final chunk, only the remaining message bytes are transferred.
Use `increment = 0` for a FIFO data register or `increment = 1, wrap = 1` for a buffer window
that the device refills or drains between triggers. The AES counter and GHASH state continue
across chunks regardless of address wrapping.

On completion of a GCM encrypt, read the computed tag from [`TAG_OUT`](registers.md#tag_out) once [`STATUS.tag_valid`](registers.md#status--tag_valid) is set.
For a GCM decrypt, a tag mismatch sets [`STATUS.tag_failed`](registers.md#status--tag_failed) and [`ERROR_CODE.aes_tag_error`](registers.md#error_code--aes_tag_error), raises the `recov_fault` alert, and suppresses `done`.
Because the plaintext is written before the tag is checked, the DMA does not provide hardware quarantine of the destination.
Suppressing `done` does not stop the CPU, another bus master, or a peripheral from reading unauthenticated plaintext.
Software must block every consumer until `tag_valid` is set and must wipe the destination before reuse when `tag_failed` is set.
Do not use inline GCM decrypt for security-sensitive plaintext if the integration cannot enforce this access discipline.
In particular, a peripheral FIFO must buffer and withhold decrypted data until authentication
succeeds; writes to a device that immediately acts on plaintext cannot be undone on tag failure.

## Error Condition

For security reasons, the DMA controller performs extensive checking of the configuration registers before starting a transfer.
If any part of the configuration is invalid, the controller reports all detected errors in the [`ERROR_CODE`](registers.md#error_code) register.
An error may also be reported during a transfer if either the source device or the destination device detects an error condition.

After an error has occurred, firmware must write a 1 to the `error` bit of the [`STATUS`](registers.md#status) register to clear the error condition before another DMA transfer can be performed.

## Device Interface Functions (DIFs)

- [Device Interface Functions](../../../../sw/device/lib/dif/dif_dma.h)
