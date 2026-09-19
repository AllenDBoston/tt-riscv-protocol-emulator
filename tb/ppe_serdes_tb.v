`timescale 1ns/1ps

module ppe_serdes_tb;

    reg clk;
    reg rst_n;
    
    // Config
    reg cfg_enable;
    reg cfg_bit_order;
    
    // TX Interface
    reg  [7:0] tx_byte_in;
    reg        tx_byte_valid;
    wire       tx_byte_pull;
    wire       tx_bit_out;
    wire       tx_bit_valid;
    reg        tx_bit_pull;
    
    // RX Interface
    reg        rx_bit_in;
    reg        rx_bit_valid;
    wire [7:0] rx_byte_out;
    wire       rx_byte_push;

    // DUT
    ppe_serdes dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_bit_order(cfg_bit_order),
        
        .tx_byte_in(tx_byte_in),
        .tx_byte_valid(tx_byte_valid),
        .tx_byte_pull(tx_byte_pull),
        
        .tx_bit_out(tx_bit_out),
        .tx_bit_valid(tx_bit_valid),
        .tx_bit_pull(tx_bit_pull),
        
        .rx_bit_in(rx_bit_in),
        .rx_bit_valid(rx_bit_valid),
        
        .rx_byte_out(rx_byte_out),
        .rx_byte_push(rx_byte_push)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz
    end

    initial begin
        $dumpfile("ppe_serdes.vcd");
        $dumpvars(0, ppe_serdes_tb);
        
        rst_n = 0;
        cfg_enable = 0;
        cfg_bit_order = 0;
        tx_byte_in = 0;
        tx_byte_valid = 0;
        tx_bit_pull = 0;
        rx_bit_in = 0;
        rx_bit_valid = 0;
        
        #100;
        rst_n = 1;
        #100;
        
        cfg_enable = 1;
        
        // ==========================================
        // TEST 1: TX Path (LSB First)
        // ==========================================
        $display("Starting TX Test (LSB First)");
        cfg_bit_order = 1; // LSB First
        
        // Present byte 0xA5 (1010_0101)
        tx_byte_in = 8'hA5;
        tx_byte_valid = 1;
        
        @(posedge clk);
        // Wait for SerDes to consume it
        while (!tx_byte_pull) @(posedge clk);
        tx_byte_valid = 0; // Clear it on next edge
        
        // Simulate encoder pulling 8 bits
        repeat(8) begin
            @(posedge clk);
            while (!tx_bit_valid) @(posedge clk);
            tx_bit_pull = 1;
            $display("TX Popped bit: %b", tx_bit_out);
            @(posedge clk);
            tx_bit_pull = 0;
            #20; // Some random wait between pulls
        end
        
        #100;
        
        // ==========================================
        // TEST 2: RX Path (MSB First)
        // ==========================================
        $display("Starting RX Test (MSB First)");
        cfg_bit_order = 0; // MSB First
        
        // Let's send 0x3C (0011_1100)
        send_rx_bit(0);
        send_rx_bit(0);
        send_rx_bit(1);
        send_rx_bit(1);
        
        send_rx_bit(1);
        send_rx_bit(1);
        send_rx_bit(0);
        send_rx_bit(0);
        
        @(posedge clk);
        if (rx_byte_push)
            $display("RX Pushed byte: %h", rx_byte_out);
            
        #100;
        $display("All Tests Completed.");
        $finish;
    end
    
    task send_rx_bit;
        input bit_val;
        begin
            @(posedge clk);
            rx_bit_in = bit_val;
            rx_bit_valid = 1;
            @(posedge clk);
            rx_bit_valid = 0;
            #30; // some time between bits
        end
    endtask

endmodule
