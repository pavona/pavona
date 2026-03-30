# Reference Manuals

* [Comportability Definition and Specification](../doc/contributing/hw/comportability/README.md)
* [Device Interface Function (DIF) Specification](../doc/contributing/sw/device_interface_functions.md)
* Tool Guides
  * [Topgen Tool](./topgen/README.md): Describes `topgen.py` and its Hjson format source.
    Used to generate RTL and validation files for top specific modules such as PLIC, pinmux, and crossbar.
  * [Register Tool](./reggen/README.md): Describes `regtool.py` and its Hjson format source.
    Used to generate documentation, RTL, header files, and validation files for IP registers and top level.
  * [Ipgen Tool](./ipgen/README.md): Describes `ipgen.py` and its Hjson control file.
    Used to generate IP blocks from IP templates.
  * [Crossbar Tool](./tlgen/README.md): Describes `tlgen.py` and its Hjson format source.
    Used to generate RTL files of the crossbars at the top level.
  * [DVSim](./dvsim/README.md): Describes `dvsim/dvsim.py`.
    Used to build and run design verification (DV) tests.
  * [Fpvgen Tool](./fpvgen/README.md): Describes `fpvgen.py`.
    Used to generate initial code for formal property verification (FPV) testbenches.
  * [Uvmdvgen Tool](./uvmdvgen/README.md): Describes `uvmdvgen.py`.
    Used to generate initial UVM-based code for DV testbenches.
  * [Device Table Tool](./dtgen/README.md): Describes `dttool.py`.
    Used to generate software device tables based on a top configuration.
  * [Vendor-In Tool](./doc/vendor.md): Describes `vendor.py` and its Hjson control file.
    Used to pull a local copy of code maintained in other upstream repositories and apply local patch sets.
  * [Design-related tooling](./design/README.md): Describes miscellaneous design-related scripts under `design/`.
    This includes a variety of generator tools and useful scripts.
  * [I2C to SVG Tool](./i2csvg/README.md): Describes `i2csvg.py`.
    Used to generate `svg` images from text files of I2C transactions.
* [FPGA Reference Manual](../doc/contributing/fpga/ref_manual_fpga.md)
* [Continuous Integration](../doc/contributing/ci/README.md)
