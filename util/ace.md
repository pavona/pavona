# Architectural Composition Engine (ACE)

Pavona is able to generate hardware synthesis files from a smaller subset of source files via the Architectural Composition Engine (ACE).
ACE is a set of tools composed of topgen, ipgen, tlgen, reggen, fpvgen, and uvmdvgen.

ACE flows include:

| Tool     | Generate...                                                   | From...                                          |
| -------- | ------------------------------------------------------------- | ------------------------------------------------ |
| topgen   | Top level collateral (RTL, software, metadata, documentation) | Top description and seed configuration           |
| ipgen    | IP block collateral (RTL, metadata, documentation)            | Templates and parameter inputs                   |
| reggen   | Register collateral (RTL, metadata, documentation, software)  | Register description within IP block description |
| tlgen    | TL-UL crossbar collateral (RTL, metadata)                     | Crossbar description within top description      |
| uvmdvgen | UVM collateral (DV code, metadata, documentation)             | An IP block name                                 |
| fpvgen   | Boilerplate FPV testbenches (DV code)                         | An RTL (SystemVerilog) file                      |
