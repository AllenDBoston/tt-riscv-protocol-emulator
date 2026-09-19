`timescale 1ns/1ps

module soc_bus (
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU Interface (PicoRV32 Native Memory Interface)
    input  wire        cpu_mem_valid,
    input  wire        cpu_mem_instr,
    output reg         cpu_mem_ready,
    input  wire [31:0] cpu_mem_addr,
    input  wire [31:0] cpu_mem_wdata,
    input  wire [3:0]  cpu_mem_wstrb,
    output reg  [31:0] cpu_mem_rdata,
    
    // Target 0: ROM (0x0000_0000 - 0x0000_07FF)
    output reg         rom_req,
    input  wire [31:0] rom_rdata,
    input  wire        rom_ack,
    
    // Target 1: SRAM Port A (0x2000_0000 - 0x2000_03FF)
    output reg         sram_req,
    output reg  [3:0]  sram_we,
    input  wire [31:0] sram_rdata,
    input  wire        sram_ack,
    
    // Target 2: PPE CSRs (0x4000_0000 - 0x4000_0014)
    output reg         csr_req,
    output reg         csr_we,
    input  wire [31:0] csr_rdata,
    input  wire        csr_ack
);

    // State machine to prevent sending requests multiple times
    reg busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_mem_ready <= 0;
            cpu_mem_rdata <= 0;
            
            rom_req  <= 0;
            sram_req <= 0;
            sram_we  <= 0;
            csr_req  <= 0;
            csr_we   <= 0;
            
            busy <= 0;
        end else begin
            cpu_mem_ready <= 0;
            
            if (cpu_mem_valid && !cpu_mem_ready && !busy) begin
                busy <= 1;
                // Decode address
                case (cpu_mem_addr[31:28])
                    4'h0: begin // ROM
                        rom_req <= 1;
                    end
                    4'h2: begin // SRAM
                        sram_req <= 1;
                        sram_we  <= cpu_mem_wstrb;
                    end
                    4'h4: begin // PPE CSR
                        csr_req <= 1;
                        csr_we  <= |cpu_mem_wstrb;
                    end
                    default: begin // Unmapped address (just return 0 immediately)
                        cpu_mem_rdata <= 32'hDEADBEEF;
                        cpu_mem_ready <= 1;
                        busy <= 0;
                    end
                endcase
            end
            
            // Handle Acknowledgements
            if (busy) begin
                if (rom_req && rom_ack) begin
                    rom_req <= 0;
                    cpu_mem_rdata <= rom_rdata;
                    cpu_mem_ready <= 1;
                    busy <= 0;
                end
                else if (sram_req && sram_ack) begin
                    sram_req <= 0;
                    sram_we  <= 0;
                    cpu_mem_rdata <= sram_rdata;
                    cpu_mem_ready <= 1;
                    busy <= 0;
                end
                else if (csr_req && csr_ack) begin
                    csr_req <= 0;
                    csr_we  <= 0;
                    cpu_mem_rdata <= csr_rdata;
                    cpu_mem_ready <= 1;
                    busy <= 0;
                end
            end
        end
    end

endmodule
