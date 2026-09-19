`timescale 1ns/1ps

module ppe_tx_encoder (
    input  wire       clk,
    input  wire       rst_n,
    
    // Config from CSRs
    input  wire       cfg_enable,
    input  wire [1:0] cfg_line_enc,   // 00=NRZ, 01=NRZI, 10=Manchester
    input  wire       cfg_stuff_en,
    input  wire [3:0] cfg_stuff_max,  // e.g., 6 for USB
    input  wire       cfg_stuff_val,  // e.g., 1 for USB
    input  wire       cfg_ins_val,    // e.g., 0 for USB
    
    // Timing
    input  wire       tick_2x,        // Pulsed twice per bit period (2x baud rate)
    
    // Interface from Serializer
    input  wire       tx_bit_in,      // Next bit from FIFO/Serializer
    input  wire       tx_valid,       // Serializer has valid data
    output reg        tx_pull,        // Encoder requests next bit (1-clock pulse)
    
    // Interface to physical pins
    output reg        tx_line_out,    // The actual encoded electrical state
    output reg        tx_line_en      // Output enable
);

    reg       phase;          // 0 = 1st half of bit, 1 = 2nd half of bit
    reg       current_bit;    // The raw bit currently being transmitted
    reg [3:0] stuff_cnt;      // Counter for consecutive bits
    reg       nrzi_state;     // Current line state for NRZI
    
    wire insert_stuff = cfg_stuff_en && (stuff_cnt == cfg_stuff_max);
    wire next_bit     = insert_stuff ? cfg_ins_val : (tx_valid ? tx_bit_in : 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase       <= 1'b0;
            current_bit <= 1'b1;
            stuff_cnt   <= 4'd0;
            nrzi_state  <= 1'b1; // Idle state for USB (J state)
            tx_pull     <= 1'b0;
            tx_line_en  <= 1'b0;
        end else if (!cfg_enable) begin
            phase       <= 1'b0;
            current_bit <= 1'b1;
            stuff_cnt   <= 4'd0;
            nrzi_state  <= 1'b1;
            tx_pull     <= 1'b0;
            tx_line_en  <= 1'b0;
        end else begin
            tx_line_en <= 1'b1;
            
            // Default tx_pull to 0 to ensure it's a 1-cycle pulse
            tx_pull <= 1'b0;

            if (tick_2x) begin
                if (phase == 1'b1) begin
                    // Transitioning to Phase 0 (Start of new bit)
                    phase <= 1'b0;
                    current_bit <= next_bit;
                    
                    if (insert_stuff) begin
                        stuff_cnt <= 4'd0;
                        // Do not pull next bit from serializer
                    end else if (tx_valid) begin
                        tx_pull <= 1'b1; // Handshake: fetch next bit
                        if (next_bit == cfg_stuff_val) begin
                            stuff_cnt <= stuff_cnt + 1;
                        end else begin
                            stuff_cnt <= 4'd0;
                        end
                    end else begin
                        stuff_cnt <= 4'd0;
                    end
                    
                    // NRZI State update (toggles if bit is 0)
                    if (cfg_line_enc == 2'b01) begin
                        if (next_bit == 1'b0) begin
                            nrzi_state <= ~nrzi_state;
                        end
                    end
                end else begin
                    // Transitioning to Phase 1 (Middle of bit)
                    phase <= 1'b1;
                end
            end
        end
    end

    // Combinatorial Output Logic
    always @(*) begin
        case (cfg_line_enc)
            2'b00: tx_line_out = current_bit; // NRZ
            2'b01: tx_line_out = nrzi_state;  // NRZI
            2'b10: tx_line_out = (phase == 1'b0) ? ~current_bit : current_bit; // Manchester
            default: tx_line_out = 1'b1;
        endcase
    end

endmodule
