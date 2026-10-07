###############################################################################
# Cobalt Boot ROM build
#
# $@ = target file
# $< = first prerequisite
# $^ = all prerequisites
# $* = target name without extension
###############################################################################

RISCV_GCC     ?= riscv64-unknown-elf-gcc
RISCV_OBJCOPY ?= riscv64-unknown-elf-objcopy
RISCV_READELF ?= riscv64-unknown-elf-readelf
RISCV_OBJDUMP ?= riscv64-unknown-elf-objdump
PYTHON        ?= python3

LINKER ?= cobalt_linker.ld

CFLAGS  = -march=rv64imafdc -mabi=lp64d
LDFLAGS = -nostdlib -static -Wl,--no-gc-sections

.PHONY: all clean

all: cobalt_boot.sv cobalt_boot.hex cobalt_boot.readelf cobalt_boot.objdump

###############################################################################
# ELF
###############################################################################

cobalt_boot.elf: cobalt_boot.S $(LINKER)
	$(RISCV_GCC) $(CFLAGS) -T$(LINKER) $(LDFLAGS) $< -o $@

###############################################################################
# Binary image
###############################################################################

cobalt_boot.bin: cobalt_boot.elf
	$(RISCV_OBJCOPY) -O binary $< $@

###############################################################################
# ROM image
#
# Pad/copy to 128-byte boundary if your ROM generator expects this.
###############################################################################

cobalt_boot.img: cobalt_boot.bin
	cp $< $@

###############################################################################
# Generate SystemVerilog ROM
###############################################################################

cobalt_boot.sv: cobalt_boot.img gen_rom.py 
	$(PYTHON) ./gen_rom.py cobalt_boot.img

###############################################################################
# Verilog HEX
###############################################################################

cobalt_boot.hex: cobalt_boot.elf
	$(RISCV_OBJCOPY) -O verilog $< $@

###############################################################################
# Inspection files
###############################################################################

cobalt_boot.readelf: cobalt_boot.elf
	$(RISCV_READELF) -a $< > $@

cobalt_boot.objdump: cobalt_boot.elf
	$(RISCV_OBJDUMP) -D -S $< > $@

###############################################################################
# Clean
###############################################################################

clean:
	rm -f *.elf *.bin *.img *.hex *.sv *.readelf *.objdump