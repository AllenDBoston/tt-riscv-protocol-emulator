# Jane Street Protocol Emulator ASIC - Project Tracker

## Project Overview
* **Goal:** Design a Programmable Protocol Engine (PPE) hybrid microarchitecture capable of emulating slow (I2C/UART) and fast (USB/Ethernet) protocols for the Jane Street Tiny Tapeout competition (IHP 130nm).
* **Architecture:** RISC-V Control Plane (handling enumeration, packet parsing) + Configurable Hardware Data Plane (handling NRZI/Manchester, Bit-stuffing, CRC, and strict timing).
* **Target Node:** IHP 130nm CMOS5L (Tiny Tapeout, 6x4 tile limit, approx 24,000 gates).

## Session Log

*Use this table to track metrics starting from the next session.*

| Session Phase | Prompts | Tokens (Est.) | Wall Time | Notes / Progress |
| :--- | :--- | :--- | :--- | :--- |
| **Session 1 (Archived)** | N/A | N/A | N/A | Brainstormed eFPGA vs. SoC. Pivoted to RISC-V + Programmable Protocol Engine (PPE) architecture to support USB/Ethernet limits. |
| **Session 2** | 5 | ~4k | ~5m | Defined the PPE microarchitecture, created the CSR memory map, resolved memory limitations via IHP SRAM macros, wrote and successfully simulated the TX Baseband Line Encoder (NRZI, Manchester, Bit-stuffing) in Verilog, and created the core architectural documentation. |
| **Session 3** | ~6 | ~6k | ~10m | Implemented the RX Decoder (Digital PLL for clock recovery & unstuffing), SerDes blocks, and the unified PPE CSR Controller (handling SRAM DMA). Successfully verified the complete top-level Tiny Tapeout wrapper hierarchy mapping out to ~1,080 standard cells in Yosys synthesis. |
| **Session 4** | ~4 | ~5k | ~8m  | Implemented the full RISC-V System-on-Chip. Replaced slow SPI XIP with a 2KB embedded ROM and a 1KB Dual-Port SRAM interconnect. Integrated the PicoRV32 core with the PPE via `soc_bus.v`. Ran a successful full-chip system synthesis mapping the entire logic budget. |

## Tested Protocols & Verification Status
*As of Session 2, the Transmit (TX) Baseband hardware has been verified using `iverilog` and `vvp`.*

*   **UART / I2C (NRZ Mode):** 
    *   *Test Method:* Injected `0xAA` (alternating bits) into `ppe_tx_encoder_tb.v` with `LINE_ENC=00` (NRZ) and Bit Stuffing disabled.
    *   *Status:* **PASS**. Verified 1:1 mapping of data to output pin.
*   **USB 1.5 Mbps (NRZI + Bit Stuffing Mode):** 
    *   *Test Method:* Injected `0x7F` (seven consecutive `1`s) with `LINE_ENC=01` (NRZI) and Bit Stuffing enabled (`MAX_RUN=6`, `INS_VAL=0`).
    *   *Status:* **PASS**. Verified that the hardware automatically stalls the serializer, inserts a `0` after the 6th `1`, and correctly toggles the NRZI line state on `0`s while maintaining state on `1`s.
*   **10BASE-T Ethernet (Manchester Mode):** 
    *   *Test Method:* Injected `0xD` (`1101`) with `LINE_ENC=10` (Manchester) and Bit Stuffing disabled.
    *   *Status:* **PASS**. Verified cycle-accurate mid-bit transitions (e.g., a logic `1` correctly generated a `0 -> 1` transition on the output pin).
