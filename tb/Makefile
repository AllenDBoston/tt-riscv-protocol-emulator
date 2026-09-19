SIM ?= iverilog
WAVES ?= vcd

all: simulate

compile:
	$(SIM) -o ppe_tx_encoder.vvp ../src/ppe_tx_encoder.v ppe_tx_encoder_tb.v
	$(SIM) -o ppe_rx_decoder.vvp ../src/ppe_rx_decoder.v ppe_rx_decoder_tb.v
	$(SIM) -o ppe_serdes.vvp ../src/ppe_serdes.v ppe_serdes_tb.v

simulate: compile
	vvp ppe_tx_encoder.vvp
	vvp ppe_rx_decoder.vvp
	vvp ppe_serdes.vvp

clean:
	rm -f *.vvp *.vcd
