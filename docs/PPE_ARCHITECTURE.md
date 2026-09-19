# Jane Street Protocol Emulator ASIC - PPE Architecture

## 1. System Overview

The **Programmable Protocol Engine (PPE)** is a hybrid microarchitecture designed for the Tiny Tapeout IHP 130nm process. Because a standard Tiny Tapeout design runs at a fixed 50 MHz clock and has strict area limitations (approx 30,000 standard cells for an 8x4 tile), emulating fast, complex protocols like USB and Ethernet entirely in software (bit-banging) is impossible.

To solve this, we partition the problem:
1. **Control Plane (RISC-V RV32I):** Handles packet generation, protocol state machines, and high-level parsing.
2. **Data Plane (PPE Baseband Hardware):** Handles cycle-accurate serialization, line coding (NRZI, Manchester), clock & data recovery (CDR), and hardware bit-stuffing.

By configuring the PPE registers, the RISC-V firmware can morph the I/O pins to behave like a USB Controller, an Ethernet MAC, a UART, or an I2C device on the fly.

---

## 2. Memory and IO Constraints

Based on the capabilities of the Tiny Tapeout IHP 130nm process:
*   **Memory:** We utilize the 1KB (1024x8) hard SRAM macro for standard TT designs. For the expanded Ethernet capability, we tile multiple macros up to 4KB.
*   **I/O Strategy:** 
    *   **SPI Execute-In-Place (XIP):** The RISC-V fetches instructions from an external SPI Flash using the dedicated `ui_in` and `uo_out` pins.
    *   **Bidirectional IOs (`uio`):** Dedicated to the PPE for half-duplex and open-drain protocols (like I2C).
*   **PHY Caveat:** Our ASIC acts as the **Baseband MAC**. For electrical compliance with protocols like USB (3.3V differential) and Ethernet (transformer-isolated), external physical transceivers (PHYs) are required on the PCB carrier.

---

## 3. PPE Datapath Architecture

The datapath is deeply pipelined to decouple the slow execution of the RISC-V from the strict line-rate of external protocols.

```text
                     +---------------------------------------+
                     |           RISC-V Core (RV32I)         |
                     +---------------------------------------+
                               | Wishbone / AHB |
                +---------------+ +---------------+ +---------------+
                |   Boot/SPI    | | 1KB Hard SRAM | |    PPE CSRs   |
                |  Controller   | |  (Code/Data)  | |   (Control)   |
                +---------------+ +---------------+ +---------------+
                                        |                   |
                               +-----------------+ +-----------------+
                               |  Tx FIFO Ctrl   | |  Rx FIFO Ctrl   |
                               +-----------------+ +-----------------+
                                        |                   |
                               +-----------------+ +-----------------+
                               |   Serializer    | |  Deserializer   |
                               +-----------------+ +-----------------+
                                        |                   |
                               +-----------------+ +-----------------+
                               |   Bit Stuffer   | | Bit Unstuffer   |
                               +-----------------+ +-----------------+
                                        |                   |
                               +-----------------+ +-----------------+
                               |  Line Encoder   | |  Line Decoder   |
                               +-----------------+ +-----------------+
                                        |                   |
                                   [ TX PINS ]         [ RX PINS ]
```

### The TX Encoder Core (`ppe_tx_encoder.v`)
The lowest level block (implemented in `src/ppe_tx_encoder.v`) translates raw bitstreams into line-encoded pulses. 
*   **Timing:** Uses a `tick_2x` input to evaluate the bit period in two halves (mandatory for Manchester encoding).
*   **Bit Stuffing:** Maintains a counter of consecutive bits. If the count reaches `cfg_stuff_max`, it automatically stalls the upstream serializer and injects a `cfg_ins_val` (e.g., a logic 0).
*   **Line Coding:** Configurable on the fly via the `cfg_line_enc` register (00=NRZ, 01=NRZI, 10=Manchester).

---

## 4. Control and Status Registers (CSRs)

The RISC-V configures the PPE via memory-mapped registers (Base `0x4000_0000`).

| Offset | Register Name | R/W | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | **`PPE_CTRL`** | R/W | Main control: Enable, Line Encoding, Bit Order, Framing. |
| `0x04` | **`PPE_BAUD`** | R/W | Clock divider and oversampling configuration. |
| `0x08` | **`PPE_STUFF`**| R/W | Bit stuffing parameters (Length, Value, Enable). |
| `0x0C` | **`PPE_SYNC`** | R/W | Hardware sync-word matching (e.g., USB SOP or Eth SFD). |
| `0x10` | **`PPE_PIN`**  | R/W | Pin routing: TX/RX split, Half-duplex, Open-drain enables. |
| `0x14` | **`PPE_FIFO`** | R/W | SRAM FIFO pointers (Base, Head, Tail) and thresholds. |
| `0x18` | **`PPE_INTEN`**| R/W | Interrupt Enable (Rx Ready, Tx Empty, Sync Detect, Error). |

---

## 5. Protocol Emulation Modes

By altering the CSRs, firmware can shift the hardware into vastly different communication forms.

### A. USB 1.5 Mbps (Low Speed)
*   **Configuration:**
    *   `PPE_BAUD` = 1.5 Mbps (Tick generated from 50MHz clock).
    *   `PPE_CTRL[LINE_ENC]` = `01` (NRZI).
    *   `PPE_CTRL[BIT_ORDER]` = `1` (LSB-first).
    *   `PPE_STUFF[EN]` = `1`, `MAX_RUN` = 6, `STUFF_VAL` = 1, `INS_VAL` = 0.
*   **Operation:** RISC-V pushes standard byte payloads to the SRAM FIFO. Hardware handles NRZI transition toggling and inserts a 0 after every 6 consecutive 1s to maintain clock sync.

### B. 10BASE-T Ethernet
*   **Configuration:**
    *   `PPE_BAUD` = 10 Mbps.
    *   `PPE_CTRL[LINE_ENC]` = `10` (Manchester).
    *   `PPE_CTRL[BIT_ORDER]` = `1` (LSB-first).
    *   `PPE_STUFF[EN]` = `0` (Disabled).
*   **Operation:** Ethernet frames do not use bit stuffing. The hardware translates every `1` to a 0->1 transition and every `0` to a 1->0 transition in the center of the bit period. The receiver uses a 4x oversampling phase-locked loop (implemented in the Rx Decoder) to recover the clock from the Manchester stream.

### C. Standard UART (115200 8N1)
*   **Configuration:**
    *   `PPE_BAUD` = 115200.
    *   `PPE_CTRL[LINE_ENC]` = `00` (NRZ).
    *   `PPE_CTRL[FRAME_MOD]` = `01` (Auto-Start/Stop insert).
*   **Operation:** The simplest mode. Firmware writes characters to the FIFO. Hardware surrounds it with a Start bit (low) and a Stop bit (high).

### D. I2C (Open Drain)
*   **Configuration:**
    *   `PPE_CTRL[LINE_ENC]` = `00` (NRZ).
    *   `PPE_PIN[OD_EN]` = `1` (Open Drain).
*   **Operation:** When transmitting a `1`, the hardware leaves the pin in High-Z, allowing an external pull-up resistor to pull the line high. When transmitting a `0`, it actively pulls the pin low.

---

## 6. Development & Testing Platform

The repository includes a simulation platform to verify protocol generation.

### Running the Verilog Tests
We use standard open-source tools (`iverilog` and `gtkwave`).

```bash
cd tb
make simulate
```

This will run the `ppe_tx_encoder_tb.v` testbench, which drives the hardware through:
1.  **NRZ Mode (UART)**
2.  **NRZI + Bit Stuffing Mode (USB)**
3.  **Manchester Mode (Ethernet)**

The output waveform (`ppe_tx_encoder.vcd`) can be viewed in GTKWave to visually confirm that bit insertions and line transitions occur at exactly the right clock phases.
