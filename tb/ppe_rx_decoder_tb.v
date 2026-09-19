`timescale 1ns/1ps

module ppe_rx_decoder_tb;

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
    reg tick_8x;
    
    // Inputs
    reg  rx_line_in;
    
    // Outputs
    wire rx_bit_out;
    wire rx_valid;

    // DUT
    ppe_rx_decoder dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_line_enc(cfg_line_enc),
        .cfg_stuff_en(cfg_stuff_en),
        .cfg_stuff_max(cfg_stuff_max),
        .cfg_stuff_val(cfg_stuff_val),
        .cfg_ins_val(cfg_ins_val),
        .tick_8x(tick_8x),
        .rx_line_in(rx_line_in),
        .rx_bit_out(rx_bit_out),
        .rx_valid(rx_valid)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz
    end

    // Tick Generation (8x oversampling)
    integer tick_div;
    always @(posedge clk) begin
        if (!rst_n) begin
            tick_div <= 0;
            tick_8x <= 0;
        end else begin
            if (tick_div == 3) begin // Arbitrary divider for test
                tick_div <= 0;
                tick_8x <= 1;
            end else begin
                tick_div <= tick_div + 1;
                tick_8x <= 0;
            end
        end
    end

    // Task to send a bit with 8 ticks of duration
    task send_line_state;
        input state;
        integer i;
        begin
            rx_line_in = state;
            for (i = 0; i < 8; i = i + 1) begin
                @(posedge clk);
                while (!tick_8x) @(posedge clk);
            end
        end
    endtask

    initial begin
        $dumpfile("ppe_rx_decoder.vcd");
        $dumpvars(0, ppe_rx_decoder_tb);
        
        rst_n = 0;
        cfg_enable = 0;
        cfg_line_enc = 2'b00;
        cfg_stuff_en = 0;
        cfg_stuff_max = 6;
        cfg_stuff_val = 1;
        cfg_ins_val = 0;
        rx_line_in = 1;
        
        #100;
        rst_n = 1;
        #100;
        
        // ==========================================
        // TEST 1: NRZ Mode (UART Style)
        // ==========================================
        $display("Starting Test 1: NRZ");
        cfg_enable = 1;
        cfg_line_enc = 2'b00;
        
        // Start bit (0)
        send_line_state(0);
        // Data bits (1, 0, 1)
        send_line_state(1);
        send_line_state(0);
        send_line_state(1);
        // Stop bit (1)
        send_line_state(1);
        
        #500;
        
        // ==========================================
        // TEST 2: NRZI + Bit Unstuffing (USB Style)
        // ==========================================
        $display("Starting Test 2: NRZI + Unstuffing");
        cfg_line_enc = 2'b01; // NRZI
        cfg_stuff_en = 1;
        
        // Reset line to idle J
        rx_line_in = 1;
        #500;
        
        // Let's send 7 consecutive '1's. In NRZI, this means NO transitions.
        // Wait, the encoder would have inserted a '0' (a transition) after 6 ones.
        // So line logic expected from TX:
        // Idle: 1
        // bit 1 (val 1): 1 (no trans)
        // bit 2 (val 1): 1
        // bit 3 (val 1): 1
        // bit 4 (val 1): 1
        // bit 5 (val 1): 1
        // bit 6 (val 1): 1
        // stuffed bit (0): 0 (transition!)
        // bit 7 (val 1): 0 (no trans)
        
        send_line_state(0); // Start packet (Sync edge)
        send_line_state(0); // 1 (val 1)
        send_line_state(0); // 2 (val 1)
        send_line_state(0); // 3 (val 1)
        send_line_state(0); // 4 (val 1)
        send_line_state(0); // 5 (val 1)
        send_line_state(0); // 6 (val 1)
        send_line_state(1); // STUFFED ZERO! (transition to 1)
        send_line_state(1); // 7 (val 1)
        
        #500;
        $display("All Tests Completed.");
        $finish;
    end

endmodule
