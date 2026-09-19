`timescale 1ns/1ps

module ppe_datapath (
    input  wire       clk,
    input  wire       rst_n,
    
    // Config from CSRs
    input  wire       cfg_enable,
    input  wire [1:0] cfg_line_enc,
    input  wire       cfg_stuff_en,
    input  wire [3:0] cfg_stuff_max,
    input  wire       cfg_stuff_val,
    input  wire       cfg_ins_val,
    input  wire       cfg_bit_order,
    
    // Timing
    input  wire       tick_2x,
    input  wire       tick_8x,
    
    // TX FIFO Interface
    input  wire [7:0] tx_byte_in,
    input  wire       tx_byte_valid,
    output wire       tx_byte_pull,
    
    // RX FIFO Interface
    output wire [7:0] rx_byte_out,
    output wire       rx_byte_push,
    
    // Physical Pins
    output wire       tx_line_out,
    output wire       tx_line_en,
    input  wire       rx_line_in
);

    // Internal connections between SerDes and Encoders/Decoders
    wire tx_bit, tx_bit_valid, tx_bit_pull;
    wire rx_bit, rx_bit_valid;

    // 1. Serializer / Deserializer
    ppe_serdes u_serdes (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_bit_order(cfg_bit_order),
        
        .tx_byte_in(tx_byte_in),
        .tx_byte_valid(tx_byte_valid),
        .tx_byte_pull(tx_byte_pull),
        
        .tx_bit_out(tx_bit),
        .tx_bit_valid(tx_bit_valid),
        .tx_bit_pull(tx_bit_pull),
        
        .rx_bit_in(rx_bit),
        .rx_bit_valid(rx_bit_valid),
        
        .rx_byte_out(rx_byte_out),
        .rx_byte_push(rx_byte_push)
    );

    // 2. TX Line Encoder
    ppe_tx_encoder u_tx_encoder (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_line_enc(cfg_line_enc),
        .cfg_stuff_en(cfg_stuff_en),
        .cfg_stuff_max(cfg_stuff_max),
        .cfg_stuff_val(cfg_stuff_val),
        .cfg_ins_val(cfg_ins_val),
        .tick_2x(tick_2x),
        
        .tx_bit_in(tx_bit),
        .tx_valid(tx_bit_valid),
        .tx_pull(tx_bit_pull),
        
        .tx_line_out(tx_line_out),
        .tx_line_en(tx_line_en)
    );

    // 3. RX Line Decoder
    ppe_rx_decoder u_rx_decoder (
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
        
        .rx_bit_out(rx_bit),
        .rx_valid(rx_bit_valid)
    );

endmodule
