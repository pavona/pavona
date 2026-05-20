# Theory of Operation

The following pseudo-code illustrates the Access Control Range Check logic, incorporating range priorities and access control rules.
The default system behavior is to deny access unless explicitly allowed by the range configuration.
The incoming address is compared against each enabled range register, and access control decisions are made based on matching and permissions.
The priority order (a lower range slot has a higher priority) of the ranges ensures that higher-priority ranges override lower-priority ones when a conflict occurs (i.e., if more than one range matches the incoming request).

```
def range_check_access(address, access_type):
  access_granted = False            # Default: access is denied
  for i = 0 to (num_ranges - 1):    # Iterate through ranges, starting from the highest priority
    if range[i].enabled:            # Only process enabled ranges
      # Address matching based on base/limit
      if (range[i].base >= address) and (address < range[i].limit):
        range_match = True
      else:
        range_match = False

      # If address matches within this range, check permissions
      if range_match:
        if access_type == EXECUTE and range[i].execute and access_role in range[i].read_perm:
	        access_granted == True
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

Additionally, we perform the deny count and the logging mechanism as follows:

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

    if deny_count >= deny_count_threshold:                      # If the count reaches the
      return DENY_COUNT_ERROR                                   # threshold, raise an error

  # If told to clear the log, reset the counter
  else if log_clear:
    deny_count = 0
    first_denied_access_log = {}
```
