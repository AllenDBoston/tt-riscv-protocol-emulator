`timescale 1ns/1ps

module ppe_rx_decoder (
    input  wire       clk,
    input  wire       rst_n,
    
    // Config from CSRs
    input  wire       cfg_enable,
    input  wire [1:0] cfg_line_enc,   // 00=NRZ, 01=NRZI, 10=Manchester
    input  wire       cfg_stuff_en,
    input  wire [3:0] cfg_stuff_max,
    input  wire       cfg_stuff_val,
    input  wire       cfg_ins_val,
    
    // Timing
    input  wire       tick_8x,        // 8x oversampling tick
    
    // Interface from physical pins
    input  wire       rx_line_in,
    
    // Interface to Deserializer
    output reg        rx_bit_out,     // Decoded bit
    output reg        rx_valid        // 1-cycle pulse when rx_bit_out is valid
);

    reg [2:0] phase;
    reg       rx_sync;                // 1 when actively receiving
    reg       rx_last_pin;            // Edge detection
    reg       rx_last_sampled;        // For NRZI comparison
    reg       manchester_first_half;  // For Manchester decoding
    reg [3:0] stuff_cnt;
    reg       decoded_bit;

    wire edge_detected = (rx_line_in != rx_last_pin);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 3'd0;
            rx_sync <= 1'b0;
            rx_last_pin <= 1'b1; // Assume idle high
            rx_last_sampled <= 1'b1;
            manchester_first_half <= 1'b0;
            stuff_cnt <= 4'd0;
            rx_bit_out <= 1'b0;
            rx_valid <= 1'b0;
        end else if (!cfg_enable) begin
            phase <= 3'd0;
            rx_sync <= 1'b0;
            rx_last_pin <= rx_line_in;
            rx_last_sampled <= 1'b1;
            stuff_cnt <= 4'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // Default to 0 (pulse)
            rx_last_pin <= rx_line_in; // Track for edge detection

            if (tick_8x) begin
                if (edge_detected) begin
                    // Resynchronize DPLL on any edge
                    if (!rx_sync && cfg_line_enc != 2'b10) begin
                        // For NRZ/NRZI, first edge starts the frame
                        rx_sync <= 1'b1;
                    end
                    phase <= 3'd0; // Reset phase to align with edge
                end else begin
                    phase <= phase + 1;
                end

                // Sample in the middle of the bit period
                // For NRZ/NRZI: Sample at phase 4
                // For Manchester: Bit period is 2 edges. We sample at phase 2 and 6.
                if (cfg_line_enc != 2'b10) begin
                    // NRZ & NRZI Logic
                    if (rx_sync && phase == 3'd4) begin
                        // Line Decoding
                        if (cfg_line_enc == 2'b01) begin
                            // NRZI: transition = 0, no transition = 1
                            decoded_bit = (rx_line_in == rx_last_sampled) ? 1'b1 : 1'b0;
                        end else begin
                            // NRZ
                            decoded_bit = rx_line_in;
                        end
                        
                        rx_last_sampled <= rx_line_in;
                        
                        // Bit Unstuffing
                        if (cfg_stuff_en) begin
                            if (stuff_cnt == cfg_stuff_max) begin
                                // This SHOULD be the stuffed bit, ignore it and reset count
                                stuff_cnt <= 4'd0;
                            end else begin
                                rx_bit_out <= decoded_bit;
                                rx_valid   <= 1'b1;
                                if (decoded_bit == cfg_stuff_val)
                                    stuff_cnt <= stuff_cnt + 1;
                                else
                                    stuff_cnt <= 4'd0;
                            end
                        end else begin
                            rx_bit_out <= decoded_bit;
                            rx_valid   <= 1'b1;
                        end
                    end
                    
                    // Timeout/Loss of sync (idle detection)
                    if (rx_sync && phase == 3'd7 && rx_line_in == 1'b1 && !edge_detected) begin
                        // Simple timeout mechanism if line stays high (idle)
                        // In reality, higher level framing handles this better.
                    end
                    
                end else begin
                    // Manchester Logic (IEEE 802.3: 0->1 transition = 1, 1->0 transition = 0)
                    // The transition happens in the middle of the bit (phase 0 due to sync).
                    // This means the valid data is known right after the edge!
                    if (edge_detected) begin
                        rx_bit_out <= rx_line_in; // If it just went HIGH, it's a 1. If LOW, it's a 0.
                        rx_valid <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
