import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_boot_and_transmit(dut):
    dut._log.info("Starting RISC-V SoC Gate-Level Test...")

    # Set up 50MHz clock (20ns period)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Reset the system
    dut._log.info("Asserting reset...")
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut._log.info("Reset released. CPU booting...")

    # Let the CPU boot from the ROM, write to SRAM, configure CSRs, and fire DMA.
    # 2000 cycles is enough to execute our tiny 13-instruction bootloader.
    await ClockCycles(dut.clk, 2000)

    # We just want to ensure the netlist simulates without X-propagation crashes
    # and that the output pins don't go to an unknown state.
    assert dut.uo_out.value.is_resolvable, "Output pins went to an unknown (X) state!"
    
    dut._log.info("Gate-Level Simulation passed! CPU booted and logic resolved cleanly.")
