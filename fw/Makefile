OUTPUT = firmware

CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy

CFLAGS = -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -Wall -Wextra
LDFLAGS = -T linker.ld -nostartfiles -Wl,--gc-sections

OBJS = start.o main.o

all: $(OUTPUT).hex

$(OUTPUT).elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

$(OUTPUT).bin: $(OUTPUT).elf
	$(OBJCOPY) -O binary $< $@

# Convert binary to exactly 512 32-bit words (2048 bytes) for the ROM
$(OUTPUT).hex: $(OUTPUT).bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@
	@echo "Firmware built successfully: $@"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o *.elf *.bin *.hex
