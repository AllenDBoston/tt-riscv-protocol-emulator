`timescale 1ns/1ps

module tb_soc;

    reg clk;
    reg rst_n;
    
    // UI Pins
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    wire [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    
    // Extracted signals
    wire ppe_tx_0 = uo_out[4];
    wire ppe_tx_en = uo_out[5];
    wire status_led_1 = uo_out[7];

    tt_um_riscv_protocol_emulator dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(1'b1),
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz
    end

    initial begin
        $dumpfile("tb_soc.vcd");
        $dumpvars(0, tb_soc);
        
        rst_n = 0;
        ui_in = 8'd0;
        
        #100;
        rst_n = 1;
        
        $display("Starting SoC Boot...");
        
        // The handcrafted firmware does:
        // 1. Set BAUD = 24
        // 2. Set CTRL = 7 (Enable=1, LSB=1, NRZI=1)
        // 3. Write 0x80, 0xC3 to SRAM (Tx FIFO)
        // 4. Set TX_CTRL to transmit 2 bytes
        // 5. Infinite Loop
        
        // Wait long enough for the RISC-V to execute the code and the PPE to shift out the bits
        #50000;
        
        $display("Simulation complete.");
        $finish;
    end

endmodule
