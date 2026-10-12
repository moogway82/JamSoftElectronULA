SOURCES=turbo_ram.vhd tm4164ea4_64k_w4.vhd JamSoftElectronULA.vhd JamSoftElectronULA_TB2.vhd JamSoftElectronULA.pcf
IMAGES=JamSoftElectronULA.bin JamSoftElectronULA_config_high.bin JamSoftElectronULA_64k.bin
OSSCADBINPATH=~/opt/oss-cad-suite/bin

all: $(SOURCES) $(IMAGES)

GHDL: $(SOURCES)
	$(OSSCADBINPATH)/ghdl -a tm4164ea4_64k_w4.vhd
	$(OSSCADBINPATH)/ghdl -e TM4164EA3_64k_W4
	$(OSSCADBINPATH)/ghdl -a turbo_ram.vhd
	$(OSSCADBINPATH)/ghdl -e turbo_ram
	$(OSSCADBINPATH)/ghdl -a -fsynopsys -fexplicit saa5050_rom_dual_port_min.vhd
	$(OSSCADBINPATH)/ghdl -e -fsynopsys -fexplicit saa5050_rom_dual_port_min 
	$(OSSCADBINPATH)/ghdl -a -fsynopsys -fexplicit saa5050.vhd
	$(OSSCADBINPATH)/ghdl -e -fsynopsys -fexplicit saa5050 
	$(OSSCADBINPATH)/ghdl -a -fsynopsys -fexplicit JamSoftElectronULA.vhd
	$(OSSCADBINPATH)/ghdl -e -fsynopsys -fexplicit JamSoftElectronULA

JamSoftElectronULA.bin: GHDL
	$(OSSCADBINPATH)/yosys -m ghdl -p 'ghdl -fsynopsys -fexplicit JamSoftElectronULA; synth_ice40 -json JamSoftElectronULA.json'
	$(OSSCADBINPATH)/nextpnr-ice40 --freq 16 --hx1k --package vq100 --asc JamSoftElectronULA.asc --json JamSoftElectronULA.json --pcf JamSoftElectronULA.pcf
	$(OSSCADBINPATH)/icepack JamSoftElectronULA.asc JamSoftElectronULA.bin

JamSoftElectronULA_config_high.bin: JamSoftElectronULA.bin
	head -c9 JamSoftElectronULA.bin > JamSoftElectronULA_config_high.bin
	printf "%b" "\02" >> JamSoftElectronULA_config_high.bin 
	tail -c32210 JamSoftElectronULA.bin >> JamSoftElectronULA_config_high.bin 

JamSoftElectronULA_64k.bin: JamSoftElectronULA_config_high.bin
	cp JamSoftElectronULA_config_high.bin JamSoftElectronULA_64k.bin
	dd if=/dev/zero ibs=1 count=33316 | LC_ALL=C tr "\000" "\377" >> JamSoftElectronULA_64k.bin

test: GHDL
	$(OSSCADBINPATH)/ghdl -a -fsynopsys -fexplicit JamSoftElectronULA_TB2.vhd 
	$(OSSCADBINPATH)/ghdl -e -fsynopsys -fexplicit JamSoftElectronULA_TB2
	$(OSSCADBINPATH)/ghdl -r -fsynopsys -fexplicit JamSoftElectronULA_TB2 --wave=JamSoftElectronULA_TB2_10.ghw --ieee-asserts=disable #--read-wave-opt=wave-opts # --stop-time=150ms

view:
	surfer JamSoftElectronULA_TB2_10.ghw -s mode7.surf.ron > /dev/null &

clean:
	rm -f JamSoftElectronULA.bin JamSoftElectronULA_64k.bin JamSoftElectronULA_config_high.bin JamSoftElectronULA.json JamSoftElectronULA.asc *.o saa5050 saa5050_rom_dual_port_min work-obj93.cf tm4164ea3_64k_w4 turbo_ram jamsoftelectronula jamsoftelectronula_tb2

prog: 
	$(OSSCADBINPATH)/iceprog JamSoftElectronULA_config_high.bin

progpi:
	pinctrl set 17 op
	pinctrl set 17 dl
	flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=1000 -w JamSoftElectronULA_64k.bin
	pinctrl set 17 ip

