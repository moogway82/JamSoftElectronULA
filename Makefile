SOURCES=tm4164ea4_64k_w4.vhd JamSoftElectronULA.vhd JamSoftElectronULA_TB2.vhd JamSoftElectronULA.pcf
IMAGES=JamSoftElectronULA.bin JamSoftElectronULA_config_medium.bin

all: $(SOURCES) $(IMAGES)

GHDL: $(SOURCES)
	~/opt/oss-cad-suite/bin/ghdl -a tm4164ea4_64k_w4.vhd
	~/opt/oss-cad-suite/bin/ghdl -e TM4164EA3_64k_W4
	~/opt/oss-cad-suite/bin/ghdl -a turbo_ram.vhd
	~/opt/oss-cad-suite/bin/ghdl -e turbo_ram
	~/opt/oss-cad-suite/bin/ghdl -a JamSoftElectronULA.vhd
	~/opt/oss-cad-suite/bin/ghdl -e JamSoftElectronULA

JamSoftElectronULA.bin: GHDL
	~/opt/oss-cad-suite/bin/yosys -m ghdl -p 'ghdl JamSoftElectronULA; synth_ice40 -json JamSoftElectronULA.json'
	~/opt/oss-cad-suite/bin/nextpnr-ice40 --freq 16 --hx1k --package vq100 --asc JamSoftElectronULA.asc --json JamSoftElectronULA.json --pcf JamSoftElectronULA.pcf
	~/opt/oss-cad-suite/bin/icepack JamSoftElectronULA.asc JamSoftElectronULA.bin

JamSoftElectronULA_config_medium.bin: JamSoftElectronULA.bin
	head -c9 JamSoftElectronULA.bin > JamSoftElectronULA_config_medium.bin
	printf "%b" "\01" >> JamSoftElectronULA_config_medium.bin 
	tail -c32210 JamSoftElectronULA.bin >> JamSoftElectronULA_config_medium.bin 

test: GHDL
	~/opt/oss-cad-suite/bin/ghdl -a JamSoftElectronULA_TB2.vhd 
	~/opt/oss-cad-suite/bin/ghdl -e JamSoftElectronULA_TB2
	~/opt/oss-cad-suite/bin/ghdl -r JamSoftElectronULA_TB2 --vcd=JamSoftElectronULA_TB2_9.vcd --ieee-asserts=disable

clean:
	rm -f $(IMAGES) JamSoftElectronULA.json JamSoftElectronULA.asc JamSoftElectronULA.o JamSoftElectronULA_TB2.o e~jamsoftelectronula.o e~jamsoftelectronula_tb2.o e~tm4164ea3_64k_w4.o tm4164ea4_64k_w4.o

prog:
	~/opt/oss-cad-suite/bin/iceprog JamSoftElectronULA_config_medium.bin

