#include <stdint.h>
#include <stdbool.h>

// Memory Map
#define SRAM_BASE 0x20000000
#define CSR_BASE  0x40000000

// CSR Registers
#define REG_CTRL      *(volatile uint32_t*)(CSR_BASE + 0x00)
#define REG_BAUD      *(volatile uint32_t*)(CSR_BASE + 0x04)
#define REG_STUFF     *(volatile uint32_t*)(CSR_BASE + 0x08)
#define REG_TX_CTRL   *(volatile uint32_t*)(CSR_BASE + 0x0C)
#define REG_RX_CTRL   *(volatile uint32_t*)(CSR_BASE + 0x10)
#define REG_INT_STS   *(volatile uint32_t*)(CSR_BASE + 0x14)

// Tx FIFO Pointer (beginning of SRAM)
volatile uint8_t* tx_fifo = (volatile uint8_t*)SRAM_BASE;

int main() {
    // 1. Disable PPE before configuring
    REG_CTRL = 0;
    
    // 2. Set Baud Rate Divisor (e.g. 24 for slow test)
    REG_BAUD = 24;
    
    // 3. Configure Bit-Stuffing (Enable=1, Val=1, Ins=0, Max=6) -> 0x63
    REG_STUFF = (6 << 4) | (0 << 2) | (1 << 1) | 1;
    
    // 4. Load some bytes into SRAM Tx FIFO
    tx_fifo[0] = 0x80; // USB SYNC
    tx_fifo[1] = 0xC3; // USB DATA
    tx_fifo[2] = 0x00; // USB EOP (will be handled by driver)
    
    // 5. Enable PPE (Enable=1, LSB-first=1, NRZI (1)=1<<2) -> 1 | 2 | 4 = 7
    REG_CTRL = 7;
    
    // 6. Start DMA TX: Length=3, Ptr=0, Active=1
    REG_TX_CTRL = (1 << 31) | (3 << 16) | 0;
    
    // Wait for TX to finish
    while ((REG_TX_CTRL >> 31) & 1) {
        // Wait loop
    }
    
    // Clear Interrupt
    REG_INT_STS = 1;
    
    while(1) {
        // Main loop
    }
    
    return 0;
}
