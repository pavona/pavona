# GPIO Demo Example

## Overview

`gpio_demo` is a demo program used to showcase basic functionality of the system.
The test itself does 2 main things:
* Echo pin changes over UART.
* Echo SPI input over UART.

## GPIO Changes Over UART
This function primarily exercises the GPIO and UART blocks.
The test monitors changing values on the GPIO line and reports them over UART.

## SPI Echo Over UART
All data input over SPI is echoed on UART in a word-aligned fashion.
