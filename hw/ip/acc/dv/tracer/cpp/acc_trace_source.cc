// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "acc_trace_source.h"

#include <algorithm>
#include <cassert>
#include <memory>

static std::unique_ptr<AccTraceSource> trace_source;

AccTraceSource &AccTraceSource::get() {
  if (!trace_source) {
    trace_source.reset(new AccTraceSource());
  }
  return *trace_source;
}

void AccTraceSource::AddListener(AccTraceListener *listener) {
  listeners_.push_back(listener);
}

void AccTraceSource::RemoveListener(const AccTraceListener *listener) {
  auto it = std::find(listeners_.begin(), listeners_.end(), listener);
  assert(it != listeners_.end());
  listeners_.erase(it);
}

void AccTraceSource::Broadcast(const std::string &trace,
                                unsigned cycle_count) {
  for (AccTraceListener *listener : listeners_) {
    listener->AcceptTraceString(trace, cycle_count);
  }
}

extern "C" void accept_acc_trace_string(const char *trace,
                                         unsigned int cycle_count) {
  assert(trace != nullptr);
  AccTraceSource::get().Broadcast(trace, cycle_count);
}
