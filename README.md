# PingPong FPGA Project

This repository contains a VHDL implementation of a simple Pong game designed
for a Xilinx Spartan-3E FPGA. The design drives a 640x480 VGA display and lets a
player move a paddle to keep the ball in play.

## What the project does
- Divides the 50 MHz board clock to generate a pixel clock.
- Generates VGA HS/VS sync timing for 640x480 @ 60 Hz.
- Draws paddles and a moving ball with color changes on collisions.
- Supports reset and paddle control inputs.
- Routes the system clock to the DAC clock output used by the onboard VGA DAC.

## Key files
- `PingPong.vhd` – main VHDL source implementing timing, game logic, and RGB output.
- `PingPong.ucf` – FPGA pin constraints for VGA and control inputs.
- `Project2PingPong.xise` – Xilinx ISE project file.
- `Ping_Pong_Project_Report.pdf` – project write-up/report.
- `PingPong.bit` – generated bitstream (from the existing build).

## Build/program (high level)
Open `Project2PingPong.xise` in Xilinx ISE 13.4 (Spartan-3E target), run
Synthesize, Implement Design, and Generate Programming File to regenerate the
bitstream, then program the FPGA as usual.
