#!/bin/sh
~/opt/oss-cad-suite/bin/ghdl -a tm4164ea4_64k_w4.vhd
~/opt/oss-cad-suite/bin/ghdl -e TM4164EA3_64k_W4
# ghdl -a dram_64k_w4.vhd
#ghdl -e dram_64k_w4
~/opt/oss-cad-suite/bin/ghdl -a JamSoftElectronULA.vhd
~/opt/oss-cad-suite/bin/ghdl -e JamSoftElectronULA

# ~/opt/oss-cad-suite/bin/ghdl -a JamSoftElectronULA_TB2.vhd
# ~/opt/oss-cad-suite/bin/ghdl -e JamSoftElectronULA_TB2
# ~/opt/oss-cad-suite/bin/ghdl -r JamSoftElectronULA_TB2 --vcd=JamSoftElectronULA_TB2_9.vcd

# ~/opt/oss-cad-suite/bin/ghdl -a JamSoftElectronULA_vidtest_TB.vhd
# ~/opt/oss-cad-suite/bin/ghdl -e JamSoftElectronULA_vidtest_TB
# ~/opt/oss-cad-suite/bin/ghdl -r JamSoftElectronULA_vidtest_TB --vcd=JamSoftElectronULA_vidtest_TB.vcd

# ~/opt/oss-cad-suite/bin/ghdl -a JamSoftElectronULA_vidtest2_TB.vhd
# ~/opt/oss-cad-suite/bin/ghdl -e JamSoftElectronULA_vidtest2_TB
# ~/opt/oss-cad-suite/bin/ghdl -r JamSoftElectronULA_vidtest2_TB --vcd=JamSoftElectronULA_vidtest_TB2.vcd

~/opt/oss-cad-suite/bin/yosys -m ghdl -p 'ghdl JamSoftElectronULA; synth_ice40 -json JamSoftElectronULA.json'

~/opt/oss-cad-suite/bin/nextpnr-ice40 --freq 16 --hx1k --package vq100 --asc JamSoftElectronULA.asc --json JamSoftElectronULA.json --pcf JamSoftElectronULA.pcf

~/opt/oss-cad-suite/bin/icepack JamSoftElectronULA.asc JamSoftElectronULA.bin
