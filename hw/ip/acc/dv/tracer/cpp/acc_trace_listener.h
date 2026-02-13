// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_HW_IP_ACC_DV_TRACER_CPP_ACC_TRACE_LISTENER_H_
#define OPENTITAN_HW_IP_ACC_DV_TRACER_CPP_ACC_TRACE_LISTENER_H_

#include <sstream>
#include <string>
#include <vector>

/**
 * Base class for anything that wants to examine trace output from ACC. The
 * simulation that hosts the tracer is responsible for setting up listeners and
 * routing the DPI `accept_acc_trace_string` calls to them.
 */
class AccTraceListener {
 public:
  /**
   * Helper function to split an ACC trace output up into individual lines.
   *
   * @param trace Trace output from ACC
   * @return A vector of lines from the trace
   */
  static std::vector<std::string> SplitTraceLines(const std::string &trace) {
    std::stringstream trace_ss(trace);
    std::string trace_line;

    std::vector<std::string> trace_lines;

    while (std::getline(trace_ss, trace_line, '\n')) {
      trace_lines.push_back(trace_line);
    }

    return trace_lines;
  }

  /**
   * Called to process an ACC trace output, called a maximum of once per cycle
   *
   * @param trace Trace output from ACC
   * @param cycle_count The cycle count associated with the trace output
   */
  virtual void AcceptTraceString(const std::string &trace,
                                 unsigned int cycle_count) = 0;
  virtual ~AccTraceListener() {}
};

#endif  // OPENTITAN_HW_IP_ACC_DV_TRACER_CPP_ACC_TRACE_LISTENER_H_
