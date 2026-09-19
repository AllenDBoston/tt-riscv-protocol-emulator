`timescale 1ns/1ps

module ppe_serdes (
    input  wire       clk,
    input  wire       rst_n,
    
    // Config from CSR
    input  wire       cfg_enable,
    input  wire       cfg_bit_order,  // 0 = MSB-first, 1 = LSB-first
    
    // ==========================================
    // TX Path (SRAM FIFO -> Encoder)
    // ==========================================
    // Interface with TX FIFO
    input  wire [7:0] tx_byte_in,     // Byte from FIFO
    input  wire       tx_byte_valid,  // FIFO has valid byte
    output reg        tx_byte_pull,   // Pop next byte from FIFO (1 cycle pulse)
    
    // Interface with TX Encoder
    output wire       tx_bit_out,     // Current bit to encoder
    output reg        tx_bit_valid,   // SerDes has a valid bit to send
    input  wire       tx_bit_pull,    // Encoder consumes bit
    
    // ==========================================
    // RX Path (Decoder -> SRAM FIFO)
    // ==========================================
    // Interface with RX Decoder
    input  wire       rx_bit_in,
    input  wire       rx_bit_valid,
    
    // Interface with RX FIFO
    output reg  [7:0] rx_byte_out,
    output reg        rx_byte_push    // Push completed byte to FIFO
);

    // TX State
    reg [7:0] tx_shift_reg;
    reg [2:0] tx_bit_cnt;
    reg       tx_busy;

    // TX Bit Order Selection
    assign tx_bit_out = cfg_bit_order ? tx_shift_reg[0] : tx_shift_reg[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift_reg <= 8'd0;
            tx_bit_cnt   <= 3'd0;
            tx_busy      <= 1'b0;
            tx_byte_pull <= 1'b0;
            tx_bit_valid <= 1'b0;
        end else if (!cfg_enable) begin
            tx_shift_reg <= 8'd0;
            tx_bit_cnt   <= 3'd0;
            tx_busy      <= 1'b0;
            tx_byte_pull <= 1'b0;
            tx_bit_valid <= 1'b0;
        end else begin
            tx_byte_pull <= 1'b0; // Default to pulse
            
            if (!tx_busy) begin
                if (tx_byte_valid) begin
                    tx_shift_reg <= tx_byte_in;
                    tx_bit_cnt   <= 3'd0;
                    tx_busy      <= 1'b1;
                    tx_bit_valid <= 1'b1;
                    tx_byte_pull <= 1'b1; // Consume byte from FIFO
                end else begin
                    tx_bit_valid <= 1'b0;
                end
            end else begin
                if (tx_bit_pull) begin
                    // Encoder consumed the bit, shift next
                    if (tx_bit_cnt == 3'd7) begin
                        // Byte finished
                        tx_busy <= 1'b0;
                        tx_bit_valid <= 1'b0;
                    end else begin
                        tx_bit_cnt <= tx_bit_cnt + 1;
                        if (cfg_bit_order) // LSB-first
                            tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        else               // MSB-first
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                end
            end
        end
    end

    // RX State
    reg [7:0] rx_shift_reg;
    reg [2:0] rx_bit_cnt;
    reg [7:0] next_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift_reg <= 8'd0;
            rx_bit_cnt   <= 3'd0;
            rx_byte_out  <= 8'd0;
            rx_byte_push <= 1'b0;
        end else if (!cfg_enable) begin
            rx_shift_reg <= 8'd0;
            rx_bit_cnt   <= 3'd0;
            rx_byte_out  <= 8'd0;
            rx_byte_push <= 1'b0;
        end else begin
            rx_byte_push <= 1'b0; // Default to pulse
            
            if (rx_bit_valid) begin
                // Shift in the new bit
                if (cfg_bit_order) // LSB-first
                    next_shift = {rx_bit_in, rx_shift_reg[7:1]};
                else               // MSB-first
                    next_shift = {rx_shift_reg[6:0], rx_bit_in};
                
                rx_shift_reg <= next_shift;
                
                if (rx_bit_cnt == 3'd7) begin
                    // Full byte received
                    rx_byte_out  <= next_shift;
                    rx_byte_push <= 1'b1;
                    rx_bit_cnt   <= 3'd0;
                end else begin
                    rx_bit_cnt <= rx_bit_cnt + 1;
                end
            end
        end
    end

endmodule
