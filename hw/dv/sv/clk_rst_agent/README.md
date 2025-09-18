# Clock and Reset UVM Agent

Clock and reset UVM Agent extended from DV library/UVM agent classes.

## Description

This agent is responsible for driving the clock and reset in a testbench. 
There should one agent instanced per reset domain if there are more than one clock/reset domain
multiple agents per clock domain will be instanced. 

Also each clock and reset agent is associated with a reset domain which will control the clocking
and reset properties. 

A delay_agent is also part of the clk_rst_agent package and provides a way to consume time at a
sequence using the delay_sequence that can execute on the delay_agent
