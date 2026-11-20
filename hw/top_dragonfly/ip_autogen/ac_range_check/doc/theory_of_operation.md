# Theory of Operation

The block sits between the unfiltered TL-UL port (`ctn_tl_h2d_i` / `ctn_tl_d2h_o`) and the filtered port towards the CTN fabric (`ctn_filtered_tl_h2d_o` / `ctn_filtered_tl_d2h_i`).
The access decision is taken combinationally from the A channel of an incoming request.
The requirements realized here are described in the [README](../README.md) and are not repeated below.

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.RACL_POLICY -->
## Request Decoding

The access type is decoded from the TL-UL opcode together with the `instr_type` field of the A-channel user bits:

Access type | Condition
------------|----------
Read        | `a_opcode == Get` and `instr_type` is a strict MuBi4 `False`
Execute     | `a_opcode == Get` and `instr_type` is a strict MuBi4 `True`
Write       | `a_opcode == PutFullData` or `a_opcode == PutPartialData`

The read and execute conditions are not complementary: an `instr_type` which is not a valid MuBi4 value makes the request neither, so no range can grant it and it is denied.

The RACL role and the CTN UID are extracted from the reserved user bits of the same channel, and the role is one-hot encoded so that the policy check reduces to a bitwise AND against the `read_perm` and `write_perm` masks of a range.
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.RACL_POLICY -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.MATCH -->
## Range Matching

[`RANGE_BASE`](registers.md#range_base) and [`RANGE_LIMIT`](registers.md#range_limit) store word-aligned addresses in bits 31:2; both are extended with two zero bits before being compared against the full request address.

The resulting top-of-range hit is qualified with [`RANGE_ATTR.enable`](registers.md#range_attr) using a *loose* MuBi4 true test, so a corrupted encoding leaves the range enabled rather than opening a hole in the address map.
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.MATCH -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.PRIORITY -->
<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.RACL_POLICY -->
## Priority Resolution

The permission fields of `RANGE_ATTR` are decoded with *strict* MuBi4 true tests, the opposite direction from `enable`: a corrupted encoding withholds the permission.

Rather than walking the ranges in order, the design builds two `NumRanges`-bit masks per access type — a grant mask marking ranges which hit the address and permit the access, and a deny mask marking ranges which hit but do not — and OR-combines them into a single `grant_mask` and `deny_mask`.
Range 0 is placed at the MSB of both, which is what implements the priority rule: the request is granted if and only if at least one range hits and `grant_mask > deny_mask`.
Since the highest-priority range occupies the most significant bit, one unsigned comparison resolves the winner without a sequential search.
Deny-by-default falls out of the same expression, as no hit means no grant.

The policy registers feeding the RACL half of this comparison are shadowed, so a mismatch between their copies raises `recov_ctrl_update_err` on an update error or `fatal_fault` on a storage error.
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.PRIORITY -->
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.RACL_POLICY -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.MATCH -->
<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.PRIORITY -->
<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.RACL_POLICY -->
## Access Check Algorithm

The same decision, expressed sequentially:

```
def range_check_access(address, access_type):
  access_granted = False            # Default: access is denied
  for i = 0 to (num_ranges - 1):    # Iterate through ranges, starting from the highest priority
    if range[i].enabled:            # Only process enabled ranges
      # Address matching based on base/limit
      if (address >= range[i].base) and (address < range[i].limit):
        range_match = True
      else:
        range_match = False

      # If address matches within this range, check permissions
      if range_match:
        if access_type == EXECUTE and range[i].execute and access_role in range[i].read_perm:
          access_granted = True
        else if access_type == READ and range[i].read and access_role in range[i].read_perm:
          access_granted = True
        else if access_type == WRITE and range[i].write and access_role in range[i].write_perm:
          access_granted = True
        else:
          access_granted = False   # No matching permissions
        # Stop after the first match (highest-priority range matched)
        break

  # Return the final access decision
  if access_granted:
    return ACCESS_GRANTED
  else:
    return ACCESS_DENIED
```
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.MATCH -->
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.PRIORITY -->
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.RACL_POLICY -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->
## Squashing of Denied Requests

Denied requests are withheld from the filtered A channel by a `tlul_request_loopback` instance, which muxes between the real target and a local error responder through a `tlul_socket_1n`.
The socket tracks outstanding transactions, so responses stay ordered when granted and denied requests are interleaved.
The request payload is never modified: a granted request is forwarded as it arrived, while the response to a denied one is assembled a cycle later from flopped copies of its opcode, size and source fields.

Whether that response carries `d_error` or fails silently is fixed at compile time by the `RangeCheckErrorRsp` parameter, not by software.
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.PERMISSIONS -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.RANGE.LOCK -->
## Range Configuration Locking

[`RANGE_REGWEN`](registers.md#range_regwen) is a per-range MuBi4 write enable with `rw0c` access, so software can only ever clear it and never restore it: a lock taken at any point holds until the next reset.
<!-- END-FEATURE: AC_RANGE_CHECK.RANGE.LOCK -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.DENY_LOG -->
## Denied Access Logging

The deny counter increments only when three conditions hold at once: [`LOG_CONFIG.log_enable`](registers.md#log_config) is set, the range which caused the denial has `RANGE_ATTR.log_denied_access` set, and the log is not being cleared in the same cycle.
That range is identified by feeding the reversed deny mask into a leading-one detector, which yields the highest-priority denying range; the index selects both the per-range logging enable and the value reported in `LOG_STATUS.deny_range_index`.

The diagnostic fields of [`LOG_STATUS`](registers.md#log_status) and [`LOG_ADDRESS`](registers.md#log_address) are written only while the counter still reads zero, which is what limits the log to a single event.
They are `hwext` registers, so the rising edge of `LOG_CONFIG.log_clear` zeroes them without software writing each field, and hardware clears `log_clear` itself in the following cycle.

```
def range_check_logging(range_idx, access_decision, address, access_type, log_clear):
  if access_decision == ACCESS_DENIED and not log_clear:        # Check for every denied access
    if deny_count == 0 and range[range_idx].log_denied_access:  # If first deny, log its info
      deny_count += 1
      first_denied_access_log = { range_idx,
                                  range[range_idx].ctn_uid,
                                  range[range_idx].racl_role,
                                  (access_type in {READ, EXECUTE}) and access_role in range[range_idx].read_perm,
                                  (access_type == WRITE) and access_role in range[range_idx].write_perm,
                                  !range_match,
                                  (access_type == EXECUTE),
                                  (access_type == WRITE),
                                  (access_type == READ),
                                  deny_count,
                                  address
                                }
    else if range[range_idx].log_denied_access:                 # Else, only increase the count
      deny_count += 1

    if deny_count > deny_count_threshold:                       # If the count exceeds the
      return DENY_COUNT_ERROR                                   # threshold, raise an error

  # If told to clear the log, reset the counter
  else if log_clear:
    deny_count = 0
    first_denied_access_log = {}
```

## Deny Counting and Interrupt

The counter is a redundant `prim_count` instance whose two directions raise `fatal_fault` on a mismatch.
It saturates rather than wrapping, so with the default `DenyCountWidth` of 8 it stops at 255, after which further denials change no observable state.
Nothing in hardware brings it back down: it returns to zero only on reset or on `LOG_CONFIG.log_clear`, which clears the counter and the first-denial diagnostics together.

`deny_cnt_reached` is a status-type interrupt asserted while `deny_cnt` is strictly greater than `LOG_CONFIG.deny_cnt_threshold`, so writing [`INTR_STATE`](registers.md#intr_state) cannot acknowledge it; the condition has to go away first.
Software has two ways to achieve that, and the choice is what defines how the block is operated:

* Clear the log, which resets the counter and begins a fresh accounting period at the cost of the recorded diagnostics.
* Raise `deny_cnt_threshold` above the current `deny_cnt`, which deasserts the interrupt while preserving both the counter and the first-denial log.

The second option is what makes the block usable during bring-up and while a production range configuration is still being developed: a low threshold surfaces the first offending access quickly, and the threshold can then be raised step by step without losing the earliest diagnostics.
This can be repeated only until the threshold reaches the top of its range; past that, and once the counter has saturated, new denials become observable again only by clearing the log or resetting the block.
<!-- END-FEATURE: AC_RANGE_CHECK.DENY_LOG -->

<!-- BEGIN-FEATURE: AC_RANGE_CHECK.BYPASS -->
## Bypass Mode

`range_check_overwrite_i` is evaluated with a strict MuBi8 true test and ORed directly into the grant condition, in parallel with the mask comparison, so the matching, permission and RACL results are still computed but no longer influence the outcome.
Nothing is denied in this mode, so the deny counter never increments and the log stays empty.
The strict test means any encoding other than `MuBi8::True` leaves filtering fully active, so a corrupted overwrite signal cannot open up the address map.
<!-- END-FEATURE: AC_RANGE_CHECK.BYPASS -->
