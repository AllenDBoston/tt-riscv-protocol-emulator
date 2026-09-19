`timescale 1ns/1ps

module tt_um_riscv_protocol_emulator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 1=output, 0=input)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // =========================================================================
    // IO Pin Mapping
    // =========================================================================
    wire uart_rx    = ui_in[1];
    wire ppe_rx_0   = ui_in[2];
    
    wire uart_tx;
    wire ppe_tx_0;
    wire ppe_tx_en;
    wire status_led_0 = ena;
    wire status_led_1;
    
    assign uo_out[0] = 1'b0;
    assign uo_out[1] = 1'b0;
    assign uo_out[2] = 1'b1;
    assign uo_out[3] = uart_tx;
    assign uo_out[4] = ppe_tx_0;
    assign uo_out[5] = ppe_tx_en;
    assign uo_out[6] = status_led_0;
    assign uo_out[7] = status_led_1;
    
    // I2C Open Drain emulaton (PPE Bidirectional pins)
    wire i2c_sda_out, i2c_sda_en;
    assign uio_out[0] = i2c_sda_out;
    assign uio_oe[0]  = i2c_sda_en;
    
    // Tie off unused bidirectionals
    assign uio_out[7:1] = 7'd0;
    assign uio_oe[7:1]  = 7'd0;

    // =========================================================================
    // RISC-V CPU (PicoRV32)
    // =========================================================================
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire [31:0] irq_vector = {30'd0, status_led_1, 1'b0};

    picorv32 #(
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1), // Full 32 regs
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT(0),
        .BARREL_SHIFTER(0),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(0),
        .CATCH_ILLINSN(0),
        .ENABLE_PCPI(0),
        .ENABLE_MUL(0),
        .ENABLE_FAST_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(1),
        .ENABLE_IRQ_QREGS(0),
        .ENABLE_IRQ_TIMER(0),
        .ENABLE_TRACE(0)
    ) cpu (
        .clk      (clk),
        .resetn   (rst_n),
        .trap     (),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .irq      (irq_vector)
    );

    // =========================================================================
    // SoC Interconnect
    // =========================================================================
    wire        rom_req;
    wire [31:0] rom_rdata;
    wire        rom_ack;
    
    wire        sram_a_req;
    wire [3:0]  sram_a_we;
    wire [31:0] sram_a_rdata;
    wire        sram_a_ack;
    
    wire        csr_req;
    wire        csr_we;
    wire [31:0] csr_rdata;
    wire        csr_ack;

    soc_bus bus (
        .clk(clk),
        .rst_n(rst_n),
        
        .cpu_mem_valid(mem_valid),
        .cpu_mem_instr(mem_instr),
        .cpu_mem_ready(mem_ready),
        .cpu_mem_addr (mem_addr),
        .cpu_mem_wdata(mem_wdata),
        .cpu_mem_wstrb(mem_wstrb),
        .cpu_mem_rdata(mem_rdata),
        
        .rom_req  (rom_req),
        .rom_rdata(rom_rdata),
        .rom_ack  (rom_ack),
        
        .sram_req  (sram_a_req),
        .sram_we   (sram_a_we),
        .sram_rdata(sram_a_rdata),
        .sram_ack  (sram_a_ack),
        
        .csr_req  (csr_req),
        .csr_we   (csr_we),
        .csr_rdata(csr_rdata),
        .csr_ack  (csr_ack)
    );

    // =========================================================================
    // Memories (ROM & SRAM)
    // =========================================================================
    rom_2k u_rom (
        .clk  (clk),
        .req  (rom_req),
        .addr (mem_addr[10:0]),
        .rdata(rom_rdata),
        .ack  (rom_ack)
    );

    wire        sram_b_req;
    wire        sram_b_we;
    wire [9:0]  sram_b_addr;
    wire [7:0]  sram_b_wdata;
    wire [7:0]  sram_b_rdata;
    wire        sram_b_ack;

    dp_sram_1k u_sram (
        .clk    (clk),
        
        .a_req  (sram_a_req),
        .a_we   (sram_a_we),
        .a_addr (mem_addr[9:0]),
        .a_wdata(mem_wdata),
        .a_rdata(sram_a_rdata),
        .a_ack  (sram_a_ack),
        
        .b_req  (sram_b_req),
        .b_we   (sram_b_we),
        .b_addr (sram_b_addr),
        .b_wdata(sram_b_wdata),
        .b_rdata(sram_b_rdata),
        .b_ack  (sram_b_ack)
    );

    // =========================================================================
    // Programmable Protocol Engine (PPE)
    // =========================================================================
    wire        ppe_cfg_enable;
    wire [1:0]  ppe_cfg_line_enc;
    wire        ppe_cfg_stuff_en;
    wire [3:0]  ppe_cfg_stuff_max;
    wire        ppe_cfg_stuff_val;
    wire        ppe_cfg_ins_val;
    wire        ppe_cfg_bit_order;
    wire        ppe_tick_2x;
    wire        ppe_tick_8x;

    wire [7:0]  ppe_tx_byte_in;
    wire        ppe_tx_byte_valid;
    wire        ppe_tx_byte_pull;
    
    wire [7:0]  ppe_rx_byte_out;
    wire        ppe_rx_byte_push;

    ppe_controller u_controller (
        .clk(clk),
        .rst_n(rst_n),
        
        .csr_req  (csr_req),
        .csr_we   (csr_we),
        .csr_addr (mem_addr[7:2]), // Word aligned
        .csr_wdata(mem_wdata),
        .csr_rdata(csr_rdata),
        .csr_ack  (csr_ack),
        
        .sram_req  (sram_b_req),
        .sram_we   (sram_b_we),
        .sram_addr (sram_b_addr),
        .sram_wdata(sram_b_wdata),
        .sram_ack  (sram_b_ack),
        .sram_rdata(sram_b_rdata),
        
        .cfg_enable(ppe_cfg_enable),
        .cfg_line_enc(ppe_cfg_line_enc),
        .cfg_stuff_en(ppe_cfg_stuff_en),
        .cfg_stuff_max(ppe_cfg_stuff_max),
        .cfg_stuff_val(ppe_cfg_stuff_val),
        .cfg_ins_val(ppe_cfg_ins_val),
        .cfg_bit_order(ppe_cfg_bit_order),
        
        .tick_2x(ppe_tick_2x),
        .tick_8x(ppe_tick_8x),
        
        .tx_byte_in(ppe_tx_byte_in),
        .tx_byte_valid(ppe_tx_byte_valid),
        .tx_byte_pull(ppe_tx_byte_pull),
        
        .rx_byte_out(ppe_rx_byte_out),
        .rx_byte_push(ppe_rx_byte_push),
        
        .irq(status_led_1) // Map PPE IRQ to CPU & LED
    );
    
    ppe_datapath u_datapath (
        .clk(clk),
        .rst_n(rst_n),
        
        .cfg_enable(ppe_cfg_enable),
        .cfg_line_enc(ppe_cfg_line_enc),
        .cfg_stuff_en(ppe_cfg_stuff_en),
        .cfg_stuff_max(ppe_cfg_stuff_max),
        .cfg_stuff_val(ppe_cfg_stuff_val),
        .cfg_ins_val(ppe_cfg_ins_val),
        .cfg_bit_order(ppe_cfg_bit_order),
        
        .tick_2x(ppe_tick_2x),
        .tick_8x(ppe_tick_8x),
        
        .tx_byte_in(ppe_tx_byte_in),
        .tx_byte_valid(ppe_tx_byte_valid),
        .tx_byte_pull(ppe_tx_byte_pull),
        
        .rx_byte_out(ppe_rx_byte_out),
        .rx_byte_push(ppe_rx_byte_push),
        
        .tx_line_out(ppe_tx_0),
        .tx_line_en(ppe_tx_en),
        .rx_line_in(ppe_rx_0)
    );

    // Dummy UART TX mapping for now
    assign uart_tx = 1'b1;
    
    // I2C Open Drain emulaton pseudo mapping
    assign i2c_sda_out = 1'b0;
    assign i2c_sda_en  = ~ppe_tx_0 & ppe_cfg_enable;

endmodule
