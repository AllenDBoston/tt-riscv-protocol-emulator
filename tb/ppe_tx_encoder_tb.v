`timescale 1ns/1ps

module ppe_tx_encoder_tb;

    reg clk;
    reg rst_n;
    
    // Config
    reg       cfg_enable;
    reg [1:0] cfg_line_enc;
    reg       cfg_stuff_en;
    reg [3:0] cfg_stuff_max;
    reg       cfg_stuff_val;
    reg       cfg_ins_val;
    
    // Timing
    reg tick_2x;
    
    // Serializer Interface
    reg  tx_bit_in;
    reg  tx_valid;
    wire tx_pull;
    
    // Pins
    wire tx_line_out;
    wire tx_line_en;

    // DUT Instantiation
    ppe_tx_encoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_line_enc(cfg_line_enc),
        .cfg_stuff_en(cfg_stuff_en),
        .cfg_stuff_max(cfg_stuff_max),
        .cfg_stuff_val(cfg_stuff_val),
        .cfg_ins_val(cfg_ins_val),
        .tick_2x(tick_2x),
        .tx_bit_in(tx_bit_in),
        .tx_valid(tx_valid),
        .tx_pull(tx_pull),
        .tx_line_out(tx_line_out),
        .tx_line_en(tx_line_en)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz
    end

    // Tick Generation (e.g. Baud rate = 1 Mbps -> tick_2x = 2 MHz)
    // 50MHz / 2MHz = 25 clocks
    integer tick_div;
    always @(posedge clk) begin
        if (!rst_n) begin
            tick_div <= 0;
            tick_2x <= 0;
        end else begin
            if (tick_div == 24) begin
                tick_div <= 0;
                tick_2x <= 1;
            end else begin
                tick_div <= tick_div + 1;
                tick_2x <= 0;
            end
        end
    end

    // Test Sequence
    initial begin
        $dumpfile("ppe_tx_encoder.vcd");
        $dumpvars(0, ppe_tx_encoder_tb);
        
        // Initialize
        rst_n = 0;
        cfg_enable = 0;
        cfg_line_enc = 2'b00;
        cfg_stuff_en = 0;
        cfg_stuff_max = 6;
        cfg_stuff_val = 1;
        cfg_ins_val = 0;
        tx_bit_in = 1;
        tx_valid = 0;
        
        #100;
        rst_n = 1;
        #100;
        
        // ==========================================
        // TEST 1: NRZ (UART Style)
        // ==========================================
        $display("Starting Test 1: NRZ");
        cfg_enable = 1;
        cfg_line_enc = 2'b00;
        cfg_stuff_en = 0;
        
        send_bits(8'b10101010, 8); // Send 0xAA
        #1000;
        
        // ==========================================
        // TEST 2: NRZI + Bit Stuffing (USB Style)
        // ==========================================
        $display("Starting Test 2: NRZI + Bit Stuffing (USB)");
        cfg_line_enc = 2'b01; // NRZI
        cfg_stuff_en = 1;
        cfg_stuff_max = 6;
        cfg_stuff_val = 1;
        cfg_ins_val = 0;
        
        // Send: 11111110 -> The encoder should stuff a 0 after the 6th '1'.
        // So line logic should be: 1, 1, 1, 1, 1, 1, (stuff 0), 1, 0
        send_bits(8'b01111111, 8); // LSB first, sending seven 1s then a 0.
        #1000;
        
        // ==========================================
        // TEST 3: Manchester (Ethernet Style)
        // ==========================================
        $display("Starting Test 3: Manchester (Ethernet)");
        cfg_line_enc = 2'b10; // Manchester
        cfg_stuff_en = 0;     // No stuffing
        
        // Send: 1011
        send_bits(8'b1101, 4);
        #1000;

        $display("All Tests Completed.");
        $finish;
    end

    // Task to feed bits matching the pull requests
    task send_bits;
        input [31:0] data;
        input integer length;
        integer i;
        begin
            tx_valid = 1;
            for (i = 0; i < length; i = i + 1) begin
                tx_bit_in = data[i];
                // Wait for the encoder to pull the bit
                @(posedge clk);
                while (!tx_pull) @(posedge clk);
            end
            tx_valid = 0;
        end
    endtask

endmodule
