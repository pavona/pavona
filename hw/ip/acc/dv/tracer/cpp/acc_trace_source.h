// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#ifndef OPENTITAN_HW_IP_ACC_DV_TRACER_CPP_ACC_TRACE_SOURCE_H_
#define OPENTITAN_HW_IP_ACC_DV_TRACER_CPP_ACC_TRACE_SOURCE_H_

#include <vector>

#include "acc_trace_listener.h"

// A source for simulation trace data.
//
// This is a singleton class, which will be constructed on the first call to
// get() or the first trace data that comes back from the simulation.
//
// The object is in charge of taking trace data from the simulation (which is
// sent by calling the accept_acc_trace_string DPI function) and passing it
// out to registered listeners.

class AccTraceSource {
 public:
  // Get the (singleton) AccTraceSource object
  static AccTraceSource &get();

  // Add a listener to the source
  void AddListener(AccTraceListener *listener);

  // Remove a listener from the source
  void RemoveListener(const AccTraceListener *listener);

  // Send a trace string to all listeners
  void Broadcast(const std::string &trace, unsigned cycle_count);

 private:
  std::vector<AccTraceListener *> listeners_;
};

#endif  // OPENTITAN_HW_IP_ACC_DV_TRACER_CPP_ACC_TRACE_SOURCE_H_
