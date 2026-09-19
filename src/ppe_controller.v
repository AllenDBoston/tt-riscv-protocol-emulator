`timescale 1ns/1ps

module ppe_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // CSR Interface
    input  wire        csr_req,
    input  wire        csr_we,
    input  wire [5:0]  csr_addr,
    input  wire [31:0] csr_wdata,
    output reg  [31:0] csr_rdata,
    output reg         csr_ack,
    
    // SRAM DMA Interface
    output reg         sram_req,
    output reg         sram_we,
    output reg  [9:0]  sram_addr,
    output reg  [7:0]  sram_wdata,
    input  wire        sram_ack,
    input  wire [7:0]  sram_rdata,
    
    // Datapath Config
    output reg         cfg_enable,
    output reg  [1:0]  cfg_line_enc,
    output reg         cfg_stuff_en,
    output reg  [3:0]  cfg_stuff_max,
    output reg         cfg_stuff_val,
    output reg         cfg_ins_val,
    output reg         cfg_bit_order,
    
    output reg         tick_2x,
    output reg         tick_8x,
    
    // TX Interface
    output reg  [7:0]  tx_byte_in,
    output reg         tx_byte_valid,
    input  wire        tx_byte_pull,
    
    // RX Interface
    input  wire [7:0]  rx_byte_out,
    input  wire        rx_byte_push,
    
    // Interrupts
    output wire        irq
);

    reg [15:0] cfg_baud_div;
    
    reg [9:0]  tx_ptr;
    reg [9:0]  tx_len;
    reg        tx_active;
    
    reg [9:0]  rx_ptr;
    reg [9:0]  rx_max;
    reg        rx_active;

    reg tx_done_irq;
    reg rx_done_irq;

    assign irq = tx_done_irq | rx_done_irq;

    // DMA & RX capture state
    reg [2:0] dma_state;
    localparam IDLE    = 0;
    localparam TX_WAIT = 1;
    localparam RX_WAIT = 2;

    reg [7:0] rx_hold_reg;
    reg       rx_pending;

    // Single unified state machine to prevent multi-driver issues
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_enable    <= 0;
            cfg_line_enc  <= 0;
            cfg_stuff_en  <= 0;
            cfg_stuff_max <= 6;
            cfg_stuff_val <= 1;
            cfg_ins_val   <= 0;
            cfg_bit_order <= 0;
            cfg_baud_div  <= 16'd24;
            
            tx_ptr <= 0;
            tx_len <= 0;
            tx_active <= 0;
            rx_ptr <= 0;
            rx_max <= 0;
            rx_active <= 0;
            
            tx_done_irq <= 0;
            rx_done_irq <= 0;
            
            csr_ack <= 0;
            csr_rdata <= 0;
            
            dma_state <= IDLE;
            sram_req <= 0;
            sram_we <= 0;
            tx_byte_valid <= 0;
            
            rx_hold_reg <= 0;
            rx_pending <= 0;
        end else begin
            // 1. Default pulses
            csr_ack <= 0;
            
            // 2. RX Byte Capture (High priority to avoid dropping bytes)
            if (rx_byte_push) begin
                rx_hold_reg <= rx_byte_out;
                rx_pending  <= 1;
            end
            
            // 3. TX Byte Pull Handshake
            if (tx_byte_pull) begin
                tx_byte_valid <= 0;
                if (tx_len > 0) tx_len <= tx_len - 1;
                tx_ptr <= tx_ptr + 1;
                if (tx_len == 1) begin
                    tx_active <= 0;
                    tx_done_irq <= 1;
                end
            end
            
            // 4. CSR Handling
            if (csr_req && !csr_ack) begin
                csr_ack <= 1;
                if (csr_we) begin
                    case (csr_addr)
                        6'h00: begin
                            cfg_enable    <= csr_wdata[0];
                            cfg_bit_order <= csr_wdata[1];
                            cfg_line_enc  <= csr_wdata[3:2];
                        end
                        6'h01: cfg_baud_div  <= csr_wdata[15:0];
                        6'h02: begin
                            cfg_stuff_en  <= csr_wdata[0];
                            cfg_stuff_val <= csr_wdata[1];
                            cfg_ins_val   <= csr_wdata[2];
                            cfg_stuff_max <= csr_wdata[7:4];
                        end
                        6'h03: begin
                            tx_ptr    <= csr_wdata[9:0];
                            tx_len    <= csr_wdata[25:16];
                            tx_active <= csr_wdata[31];
                        end
                        6'h04: begin
                            rx_ptr    <= csr_wdata[9:0];
                            rx_max    <= csr_wdata[25:16];
                            rx_active <= csr_wdata[31];
                        end
                        6'h05: begin
                            if (csr_wdata[0]) tx_done_irq <= 0;
                            if (csr_wdata[1]) rx_done_irq <= 0;
                        end
                    endcase
                end else begin
                    case (csr_addr)
                        6'h00: csr_rdata <= {28'd0, cfg_line_enc, cfg_bit_order, cfg_enable};
                        6'h01: csr_rdata <= {16'd0, cfg_baud_div};
                        6'h02: csr_rdata <= {24'd0, cfg_stuff_max, 1'b0, cfg_ins_val, cfg_stuff_val, cfg_stuff_en};
                        6'h03: csr_rdata <= {tx_active, 5'd0, tx_len, 6'd0, tx_ptr};
                        6'h04: csr_rdata <= {rx_active, 5'd0, rx_max, 6'd0, rx_ptr};
                        6'h05: csr_rdata <= {30'd0, rx_done_irq, tx_done_irq};
                        default: csr_rdata <= 32'd0;
                    endcase
                end
            end
            
            // 5. SRAM DMA Arbiter
            case (dma_state)
                IDLE: begin
                    sram_req <= 0;
                    if (rx_pending && rx_active && rx_max > 0) begin
                        sram_req <= 1;
                        sram_we  <= 1;
                        sram_addr <= rx_ptr;
                        sram_wdata <= rx_hold_reg;
                        dma_state <= RX_WAIT;
                    end else if (tx_active && tx_len > 0 && !tx_byte_valid && !tx_byte_pull) begin
                        sram_req <= 1;
                        sram_we  <= 0;
                        sram_addr <= tx_ptr;
                        dma_state <= TX_WAIT;
                    end
                end
                
                TX_WAIT: begin
                    if (sram_ack) begin
                        sram_req <= 0;
                        tx_byte_in <= sram_rdata;
                        tx_byte_valid <= 1;
                        dma_state <= IDLE;
                    end
                end
                
                RX_WAIT: begin
                    if (sram_ack) begin
                        sram_req <= 0;
                        rx_ptr <= rx_ptr + 1;
                        rx_pending <= 0;
                        if (rx_max > 0) begin
                            rx_max <= rx_max - 1;
                            if (rx_max == 1) begin
                                rx_active <= 0;
                                rx_done_irq <= 1;
                            end
                        end
                        dma_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // ==========================================
    // Baud Generator
    // ==========================================
    reg [15:0] baud_cnt;
    reg [1:0]  tick_8x_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt    <= 0;
            tick_8x_cnt <= 0;
            tick_8x     <= 0;
            tick_2x     <= 0;
        end else if (cfg_enable) begin
            tick_8x <= 0;
            tick_2x <= 0;
            if (baud_cnt == cfg_baud_div) begin
                baud_cnt <= 0;
                tick_8x  <= 1;
                if (tick_8x_cnt == 3) begin
                    tick_8x_cnt <= 0;
                    tick_2x     <= 1;
                end else begin
                    tick_8x_cnt <= tick_8x_cnt + 1;
                end
            end else begin
                baud_cnt <= baud_cnt + 1;
            end
        end
    end

endmodule