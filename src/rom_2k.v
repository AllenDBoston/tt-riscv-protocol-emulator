`timescale 1ns/1ps

module rom_2k (
    input  wire        clk,
    input  wire        req,
    input  wire [10:0] addr, // Byte address (up to 2047)
    output reg  [31:0] rdata,
    output reg         ack
);

    // 512 x 32-bit words = 2048 bytes
    reg [31:0] mem [0:63];

    // Optional: Load firmware if present
    initial begin
        $readmemh("../firmware.hex", mem, 0, 63);
    end

    always @(posedge clk) begin
        ack <= 0;
        if (req && !ack) begin
            rdata <= mem[addr[7:2]];
            ack <= 1;
        end
    end

endmodule
