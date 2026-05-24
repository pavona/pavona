# Get an FPGA Board

This page lists a few of the current emulation platforms supported by the Pavona project.
The project is happy to consider inclusion of other platforms and is currently evaluating additional general purpose FPGA design emulation platforms.

## NewAE CW340

Available at [Mouser](https://www.mouser.com/access/?pn=343-NAE-CW340-OTKIT).

### HyperDebug Board

The CW340 base board has ST Zio connectors to facilitate connecting an STM32 NUCLEO-L552ZE-Q board (the "HyperDebug") to act as an intermediary between your host machine and your hardware (emulated on the FPGA).
Pavona provides firmware and tooling (inside `opentitanlib`) to interact with an emulated chip using HyperDebug.
To enable more advanced test cases, you can purchase a NUCLEO Hyberdebug from either:
- [DigiKey](https://www.digikey.com/en/products/detail/stmicroelectronics/nucleo-l552ze-q/11501277)
- [Mouser](https://www.mouser.com/ProductDetail/STMicroelectronics/NUCLEO-L552ZE-Q?qs=%252B6g0mu59x7JMzV%2FcT2vTmQ%3D%3D)
- [Newark](https://www.newark.com/stmicroelectronics/nucleo-l552ze-q/dev-board-32bit-arm-cortex-m33f/dp/52AH4118)

## NewAE CW310 (Kintex XC7K410T FPGA version only)

Available at [Mouser](https://www.mouser.com/access/?pn=343-NACW310K410TNORM) or the [NewAE Technology web store](https://www.newae.com/product-page/cw310-bergen-board-large-fpga-k410t-for-full-emulation).

### Notes

The board is available in two options.
The normal option is suitable for e.g. regular hardware and software development.
If you also plan to do Side Channel Analysis (SCA), you should make sure to order the SCA option which removes some decoupling capacitors.
