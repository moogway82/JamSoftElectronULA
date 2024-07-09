SOURCES=turbo_ram.vhd tm4164ea4_64k_w4.vhd JamSoftElectronULA.vhd JamSoftElectronULA_TB2.vhd JamSoftElectronULA.pcf
IMAGES=JamSoftElectronULA.bin JamSoftElectronULA_config_medium.bin JamSoftElectronULA_64k.bin
OSSCADBINPATH=~/opt/oss-cad-suite/bin

all: $(SOURCES) $(IMAGES)

GHDL: $(SOURCES)
	$(OSSCADBINPATH)/ghdl -a tm4164ea4_64k_w4.vhd
	$(OSSCADBINPATH)/ghdl -e TM4164EA3_64k_W4
	$(OSSCADBINPATH)/ghdl -a turbo_ram.vhd
	$(OSSCADBINPATH)/ghdl -e turbo_ram
	$(OSSCADBINPATH)/ghdl -a JamSoftElectronULA.vhd
	$(OSSCADBINPATH)/ghdl -e JamSoftElectronULA

JamSoftElectronULA.bin: GHDL
	$(OSSCADBINPATH)/yosys -m ghdl -p 'ghdl JamSoftElectronULA; synth_ice40 -json JamSoftElectronULA.json'
	$(OSSCADBINPATH)/nextpnr-ice40 --freq 16 --hx1k --package vq100 --asc JamSoftElectronULA.asc --json JamSoftElectronULA.json --pcf JamSoftElectronULA.pcf
	$(OSSCADBINPATH)/icepack JamSoftElectronULA.asc JamSoftElectronULA.bin

JamSoftElectronULA_config_medium.bin: JamSoftElectronULA.bin
	head -c9 JamSoftElectronULA.bin > JamSoftElectronULA_config_medium.bin
	printf "%b" "\01" >> JamSoftElectronULA_config_medium.bin 
	tail -c32210 JamSoftElectronULA.bin >> JamSoftElectronULA_config_medium.bin 

JamSoftElectronULA_64k.bin: JamSoftElectronULA.bin
	cp JamSoftElectronULA.bin JamSoftElectronULA_64k.bin
	dd if=/dev/zero ibs=1 count=33316 | LC_ALL=C tr "\000" "\377" >> JamSoftElectronULA_64k.bin

test: GHDL
	$(OSSCADBINPATH)/ghdl -a JamSoftElectronULA_TB2.vhd 
	$(OSSCADBINPATH)/ghdl -e JamSoftElectronULA_TB2
	$(OSSCADBINPATH)/ghdl -r JamSoftElectronULA_TB2 --vcd=JamSoftElectronULA_TB2_9.vcd --ieee-asserts=disable

clean:
	rm -f JamSoftElectronULA.bin JamSoftElectronULA_64k.bin JamSoftElectronULA_config_medium.bin JamSoftElectronULA.json JamSoftElectronULA.asc JamSoftElectronULA.o JamSoftElectronULA_TB2.o e~jamsoftelectronula.o e~jamsoftelectronula_tb2.o e~tm4164ea3_64k_w4.o tm4164ea4_64k_w4.o e~turbo_ram.o turbo_ram.o work-obj93.cf tm4164ea3_64k_w4 turbo_ram jamsoftelectronula jamsoftelectronula_tb2

prog: 
	$(OSSCADBINPATH)/iceprog JamSoftElectronULA.bin

progpi:
	pinctrl set 17 op
	pinctrl set 17 dl
	flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=1000 -w JamSoftElectronULA_64k.bin
	pinctrl set 17 ip

