`timescale 1ns/1ps

module dp_sram_1k (
    input  wire        clk,
    // Port A: CPU (32-bit)
    input  wire        a_req,
    input  wire [3:0]  a_we,
    input  wire [9:0]  a_addr, // 10-bit byte address (bottom 2 bits usually 0)
    input  wire [31:0] a_wdata,
    output reg  [31:0] a_rdata,
    output reg         a_ack,
    
    // Port B: PPE (8-bit)
    input  wire        b_req,
    input  wire        b_we,
    input  wire [9:0]  b_addr,
    input  wire [7:0]  b_wdata,
    output reg  [7:0]  b_rdata,
    output reg         b_ack
);

    // 1024 bytes of memory
    reg [7:0] mem [0:1023];

    // Port A (CPU) - 32-bit access
    always @(posedge clk) begin
        a_ack <= 0;
        if (a_req && !a_ack) begin
            if (a_we[0]) mem[{a_addr[9:2], 2'b00}] <= a_wdata[7:0];
            if (a_we[1]) mem[{a_addr[9:2], 2'b01}] <= a_wdata[15:8];
            if (a_we[2]) mem[{a_addr[9:2], 2'b10}] <= a_wdata[23:16];
            if (a_we[3]) mem[{a_addr[9:2], 2'b11}] <= a_wdata[31:24];
            
            a_rdata <= {
                mem[{a_addr[9:2], 2'b11}],
                mem[{a_addr[9:2], 2'b10}],
                mem[{a_addr[9:2], 2'b01}],
                mem[{a_addr[9:2], 2'b00}]
            };
            a_ack <= 1;
        end
    end

    // Port B (PPE) - 8-bit access
    always @(posedge clk) begin
        b_ack <= 0;
        if (b_req && !b_ack) begin
            if (b_we) begin
                mem[b_addr] <= b_wdata;
            end
            b_rdata <= mem[b_addr];
            b_ack <= 1;
        end
    end

endmodule
