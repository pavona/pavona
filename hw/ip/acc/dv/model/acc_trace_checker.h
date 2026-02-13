// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#ifndef OPENTITAN_HW_IP_ACC_DV_MODEL_ACC_TRACE_CHECKER_H_
#define OPENTITAN_HW_IP_ACC_DV_MODEL_ACC_TRACE_CHECKER_H_

// A singleton class that listens to trace entries from the simulated core (as
// an AccTraceListener) and compares them with the trace coming out of the
// stepped ISS process.
//
// Trace entries from the simulated core appear as a result of DPI callbacks,
// so there's no way to propagate errors when they appear. ISS trace entries
// arrive through a synchronous interface, so the checker reports any mismatch
// at that point.
//
// For example, if "RTL A" means "trace event A from RTL" and "ISS B" means
// "trace event B from ISS" then the following is a correct series of trace
// events:
//
//     RTL A; ISS A; ISS B; RTL B ...
//
// None of these are valid:
//
//     RTL A; RTL B; ...  (*)
//     ISS A; ISS B; ...
//     RTL A; ISS B; ...
//
// The only way that an invalid trace is not reported is if no ISS trace events
// appear after the error. Trace (*), above, is an example of this. Another
// example would be if the last trace events were one of:
//
//     ...; ISS A; RTL B
//     ...; ISS A           (and nothing else)
//
// To catch these cases, the ISS simulation must call the Finish() method when
// it is done (which checks there are no outstanding events missing).

#include <iosfwd>
#include <string>
#include <vector>

#include "acc_trace_entry.h"
#include "acc_trace_listener.h"

class AccTraceChecker : public AccTraceListener {
 public:
  AccTraceChecker();
  ~AccTraceChecker();

  // Get the singleton object
  static AccTraceChecker &get();

  // Take a trace entry from the wrapped RTL. Any mismatch error is stored
  // until the next call to an API function that can respond with the error.
  void AcceptTraceString(const std::string &trace,
                         unsigned int cycle_count) override;

  // Take a trace entry from the wrapped ISS.
  //
  // Prints an error message to stderr and returns false on mismatch.
  bool OnIssTrace(const std::vector<std::string> &lines);

  // Flush any pending entries. We need to do this on reset, to handle
  // the case where we reset the processor in the middle of a stall.
  void Flush();

  // Call this when the ISS simulation completes an operation (on ECALL or
  // error).
  //
  // Prints an error message to stderr and returns false if it detects a
  // mismatch.
  bool Finish();

  // Return and clear the ISS data for the last pair of trace entries that went
  // through MatchPair if there is any.
  const AccIssTraceEntry::IssData *PopIssData();

  // Tell the model not to execute checks to see if secure wiping has written
  // random data to all registers before wiping them with zeroes on the next
  // secure wipe entry.
  void set_no_sec_wipe_chk();

 private:
  // If rtl_pending_ and iss_pending_ are not both true, return true
  // immediately with no other change. Otherwise, compare the two pending trace
  // entries. If they match, clear them both and return true. If not, print a
  // message to stderr and return false.
  bool MatchPair();

  bool rtl_started_;
  bool rtl_pending_;
  AccTraceEntry rtl_entry_;

  bool iss_started_;
  bool iss_pending_;
  AccIssTraceEntry iss_entry_;

  bool done_;
  bool seen_err_;

  // The ISS entry for the last pair of trace entries that went through
  // MatchPair.
  bool last_data_vld_;
  AccIssTraceEntry::IssData last_data_;
  bool no_sec_wipe_data_chk_;
};

#endif  // OPENTITAN_HW_IP_ACC_DV_MODEL_ACC_TRACE_CHECKER_H_
