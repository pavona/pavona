<%text># Theory of Operation</%text>

<!-- BEGIN-FEATURE: XBAR.ROUTING -->
<%text>### Overview</%text>

The crossbar is a communication component that allows transactions between multiple host and device IPs. While the crossbar does not require any particular communication protocol, as of now comportable devices in Pavona use [TileLink (TL-UL)](https://static.dev.sifive.com/docs/tilelink/tilelink-spec-1.7-draft.pdf) as its bus fabric protocol. Navigate [here](../../../../../hw/ip/tlul/README.md) for more information on comportable top level TL-UL bus functionality.

<!-- BEGIN-FEATURE: XBAR.ERROR -->
<!-- BEGIN-FEATURE: XBAR.TRANSACTION_DELAYS -->
<%text>### Address-Based Routing</%text>

The crossbar routes incoming transactions to the appropriate destination device using a programmable address map.

Each incoming request is decoded to determine its destination. If the address belongs to a valid device, the transaction is forwarded to that device. If no valid destination exists, the crossbar generates an error response without forwarding the transaction.

The crossbar also supports backpressure by allowing either side of the interface to stall with variable delays
<!-- END-FEATURE: XBAR.ROUTING -->
<!-- END-FEATURE: XBAR.ERROR -->
<!-- END-FEATURE: XBAR.TRANSACTION_DELAYS -->

<!-- BEGIN-FEATURE: XBAR.CONCURRENCY -->
<%text>### Multi-Host Arbitration</%text>

Multiple hosts may request access to the same destination simultaneously. When contention occurs, the crossbar arbitrates between competing requests without dropping any. Additionally, one of the devices of a crossbar is allowed to be another crossbar, such that a hierarchy of devices can be referenced.
<!-- END-FEATURE: XBAR.CONCURRENCY -->

<!-- BEGIN-FEATURE: XBAR.ERROR -->
<%text>### Robustness and Recovery</%text>

The crossbar correctly operates and error-handles under adverse operating conditions, like random traffic patterns, communication delays, unmapped transactions, and simultaneous activity from many hosts.
<!-- END-FEATURE: XBAR.ERROR -->
