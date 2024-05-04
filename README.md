# JamSoftElectronULA

A project to replace the original Acorn Electron ULA with a ice40 based FPGA board, by Chris Jamieson.

![Nice shot of the JamSoftElectronULA board](Photos/JamSoftElectronULA-v30-sitting-nicely.jpg "The JamSoftElectronULA board")

This is a no-frills* ULA replacement meaning that it just replicates the stock Acorn Electron ULA without adding new features. It requires the standard Electron DRAM, ROM and CPU and other components to be present and working as a normal ULA would.

Features:

- Keyboard controls: CAPS LED, Break, Ctrl+Break & Shift Break as you'd expect
- Tape interface: loading, saving and remote motor control works great using standard cables
- RGB output using RGBtoHDMI adapter works great
- Composite Out (Mono and colour with jumper)
- RF Out seems fine too
- DRAM Controller - uses the normal 4164 DRAM chips
- Usual Electron-y things!

Examples of various games known to work:

- Firetrack
- Sphere of Desiny
- Chuckie Egg
- Exile
- Citadel
- Joe Blade
- Imogen
- ElectroBots
- 0xC0DE's Bouncing Basketball & Vertical Rupture demos
- Snapper
- Elite
- Zalaga
- Cylon Attack
- Galaforce & Galaforce 2
- Southern Belle
- ...and many more...

Peripherals Tested and working:

- ElkSD
- First Byte Joystick Interface Clone (my [Least Bit Joystick Interface](https://github.com/moogway82/TheLeastBitJoystickInterface))

Missing features:

- NMI signal is ignored at present, so the Elk will likely crash with any peripheral that tries to use it (this functionality could be added to VHDL code if required, the signal is connected to the FPGA)

## Development, Testing and Current State

The bulk of development and testing has been done on 2 boards with the following specifications:

- A repaired Issue 6 board with a Rockwell R6502 and 4x Samsung KM4164B-15 DRAM chips. Tested with and without IC18 to buffer/unbuffer the 16MHz clock, PHI0 and NMI signals.
- An Issue 4 board with a UMC UM6502 and 4x TI TMS4164-15 DRAM chips.
- A repaired Issue 6 Electon PSU Board, powered from a non-original 12V AC Adapter

The JamSoftElectronULA is being provided as-is, with no guarantees. I've had a lot of issues come and go with reliability during the course of development and testing but I think it's in a good-enough state now to get out there and not be just sitting on my workbench.

I think a lot of the reliability issues I've had boil down to:

- Questionable state of my Electron boards. My issue 6 came without ULA (can you guess the reason for this project? :) ) and needed a lot of repair work and the Issue 4 was also from salvage.
- Bad ULA socket - I think I damaged some of the pin sockets on the boards with an original ULA that still had some solder left on it's pins. Re-seating the JamSoftElectronULA, testing and bending pins has been required to make more reliable connections.
- Iffy PSU. The power supply I'm using has had repairs and is running off a 12V AC adapter instead of the 19V AC of the original Elk. I also think my FPGA board may be more sensitive to power issues that the original Acorn ULA.

I've also sunk about as much time and money into this project as I wish to at present, so I'm drawing a line and publishing where I'm at. Hopefully it can help to resurrect some dead Electrons and if it needs some more development I'm hoping that perhaps others can continue this and create their own versions with fixes and improvements. Good luck!

[Some of the development history on Stardot Forums](https://stardot.org.uk/forums/viewtopic.php?t=26929)

## * Well, 1 Frill, actually...

The 1 'frill' with the current version is a simple Turbo mode which can be enabled using the key combo Ctrl + Caps + 2. The turbo mode uses the 8KB of embeded Block RAM on the FPGA as fast, 2MHz CPU clock & un-contended RAM which replaces the lower 8K of memory from the slower DRAM and provides a decent speed boost, especially in Modes 0-4 where the CPU is usually halted when trying to access RAM duing an active scanline. Normal speed is resumed as soon as a Break is issued. This almost gets the Elk up to BBC B speeds on the ClockSp benchmark. Many thanks to the [Ramtop-Retro's OSTC project](https://github.com/ramtop-retro/ostc) for providing the inspiration here.

Ideas for future 'Frills' could be:

- Add MMFS and connect an SD-Card to the FPGA programming pins
- Connect a NES joypad to the Programming pins
- Mode 7 support
- Multiple ROM support 
- ...whatever you can think of, the code's all here, knock yourself out!

# Building your own

The current design is made of 2 PCBs: a main 'TOP' board with the FPGA and most components and a 'BOTTOM' socket adapter board with a few pull-ups on it. The two boards are sandwiched together using short header pins. I made it this way to keep the overall footprint as small as possible and make it look a bit more ULA-chip-like than a big daughter board would have. Although, I do admit that a larger board would've been easier to make and assemble... feel free to make your own version :)

![Photo showing how the two halves of the JamSoftElectronULA go together](Photos/JamSoftElectronULA-v30-showing-two-halves.jpg "How the 2 boards go together")

## Gerber, BOM & Pick and Place Files

The BOM has order numbers for either LCSC or JLCPCB to keep the costs to a minimum, especially for the passives and connectors. However the FPGA is not readily available from these sources, so you might need to get that from elsewhere. It does make it quite easy to have the boards created and populated by JLCPCB which is convenient.

Fabrication Files:

### TOP PCB:

- [Gerbers](Hardware/TOP%20Board/Gerber_PCB_JamSoftElectronULA_TOP.zip)
- [BOM](Hardware/TOP%20Board/BOM_JamSoftElectronULA_TOP.csv)
- [Pick & Place](Hardware/TOP%20Board/PickAndPlace_PCB_JamSoftElectronULA_TOP.csv)

### BOTTOM PCB:

- [Gerbers](Hardware/BOTTOM%20Board/Gerber_PCB_JamSoftElectronULA_BOT.zip)
- [BOM](Hardware/BOTTOM%20Board/BOM_JamSoftElectronULA_TOP.csv)
- [Pick & Place](Hardware/BOTTOM%20Board/PickAndPlace_PCB_JamSoftElectronULA_TOP.csv)

## Assembly tips

Helpful Files:

- [Full Schematics](Hardware/Schematic_JamSoftElectronULA.pdf)
- [Interactive BOM Map](Hardware/ibom.html)
- [TOP PCB upperside image](Hardware/TOP%20Board/PCB_JamSoftElectronULA_TOP_under.pdf)
- [TOP PCB underside image](Hardware/TOP%20Board/PCB_JamSoftElectronULA_TOP_under.pdf)
- [BOTTOM PCB upperside image](Hardware/BOTTOM%20Board/PCB_JamSoftElectronULA_BOT_above.pdf)
- [BOTTOM PCB underside image](Hardware/BOTTOM%20Board/PCB_JamSoftElectronULA_BOT_under.pdf)


I'd recommend having JCLPCB assemble all the passives on the top board as these are very fiddly and time-consuming to do by hand.

Take your time soldering the FPGA and Level Shifters - use plenty of good flux. I test all adjacent pins for shorts, it can be very hard to spot some bridges. And, I prod each pin under the microscope to see if any move and need to be reflowed. I spent a couple of months troubleshooting my first prototype board only to find that the problems were caused by some very bad soldering and loads of poorly connected pins!

Make sure to check the soldering on the underside of the TOP board and the top-side of the BOTTOM board before sandwiching them with header pins as it will be hard to fix these afterwards. I always like to check resistance and continuity on the power lines (5V, 3.3V and 1.2V) and GND before commiting. You'll get a quick 'beep' on continuity mode until the capacitors charge, but it should not be maintained otherwise there is a short somewhere.

Be careful when joining the two boards to ensure that components on the facing surfaces don't make contact and create bridges or shorts. I think a 2.5mm-3mm gap, the standard insulation hight on header pins, is enough clearance, but do double check. Also, the socket pins on the BOTTOM board may have solder peaks on them that might need smoothing off.

# Building Firmware and Programming

## Building

On Linux:

Download the FPGA toolchain as provided in the releases by [YoSysHQ OSS-CAD-Suite-build project](https://github.com/YosysHQ/oss-cad-suite-build) unzip it to the directory of your choice (I use '~/opt/oss-cad-suite').

Edit the path in the Make file to where the 'oss-cad-suite' bin folder is:

```
OSSCADBINPATH=~/opt/oss-cad-suite/bin
```
Other common *NIX tools used by the Makefile are: head, printf & tail

The just run the Makefile.

```
make
```

## Programming the FPGA

### On Linux:

There is a pre-build binary configuration file in the HDL folder [JamSoftElectronULA_config_medium.bin](HDL/JamSoftElectronULA_config_medium.bin), but the iceprog tool will still be required to program it to the configuation ROM using the Makefile.

Programming the firmware can be done using a [cheap FT232H board](https://www.aliexpress.com/item/32817060303.html) (FT2232H boards can be used to also). With the JamSoftElectronULA board out of the Electron socket, connect the programming pins as shown:

| JamSoftElectronULA J1 pin | FT232H pin     | 
| ------------------------- | -------------- |
| 1 CS                      | AD4            | 
| 2 CDONE                   | AD6            |
| 3 SPICLK                  | AD0            |
| 4 CRESET                  | AD7            |
| 5 CIPO                    | AD2            |
| 6 +3.3V                   | +3.3V          |
| 7 COPI                    | AD1            |
| 8 GND                     | GND            |

![Programmer pin numbers of the JamSoftElectronULA](Photos/JamSoftElectronULA-v30-programmer-pinout.jpg "Pinout of the programming header")

![Programmer connected to the JamSoftElectronULA](Photos/JamSoftElectronULA-v30-connected-to-programmer.jpg "Programmer connected to the JamSoftElectronULA")


And then run:

```
make prog
```

It should upload and verify and you're good to pop it in the Electron.

There are a few Test Bench (TB) VHDL files in the project, they're a bit messy and just testing whatever I needed at the time to debug. I've left them in the project as there is hopefully some useful stuff in there.

Tests can be run using:
```
make test
```
And the resulting .vcd file can be analysed using gtkwave, also provided in the OSS CAD Suite Build project.

### On a Raspberry Pi:

If you don't have the FT232H or FT2232H boards, you can use a Raspberry Pi.

With Raspbian OS installed, this repo and an internet connection, enable the SPI port on the Pi by running:
```
sudo raspi-config 
```
And select "P4 SPI" under the "Interfacing" options.

Install Flashrom tool:
```
sudo apt install git libpci-dev libusb-1.0-0 libusb-dev
git clone https://github.com/flashrom/flashrom.git
cd flashrom
make
sudo make install
```

Then connect the board with the following cabling:

| Raspberry Pi 1 | JamSoftElectronULA |
| -------------- | ------------------ |
| 1 3v3          | 6 3v3              |
| 6 GND          | 8 GND              |
| 11 GPIO 17     | 4 CRESET           |
| 19 MOSI        | 7 COPI             |
| 21 MISO        | 5 CIPO             |
| 23 SCLK        | 3 SPICLK           |
| 24 SPI0 CE0    | 1 CS               |

And then run:
```
make progpi
```

### On Mac OS X:

I used to use Mac OS X for development so the Linux instructions should work there too, but I've not tested things on that platform for a while now...

### On Windows:

Sorry I can't help for Windows as I'm unsure of the state of any of these tools in that environment, sorry...

# Installing into the Electron

Replace the 68-pin socket with either a good quality 68-pin 11x11 PGA Socket or just some nice [round-pin SIL female headers](https://hobbycomponents.com/connectors/392-01-254mm-40way-sil-turned-pin-m-f-headers-pack-of-5) and cut them up to fit.

![Electron with 68-pin ULA socket installed](Photos/Electron-with-ULA-socket-installed.jpg "Electron with 68-pin ULA socket installed")

Take care to align the pins and orient the board with the cut-corner to the dot shown on the Elk mainboard silkscreen and press down firmly to make a good connection. There isn't much cleance between it and the keyboard but it should fit in.

![JamSoftElectronULA installed into the Electron](Photos/JamSoftElectronULA-v30-installed-into-Electron.jpg "JamSoftElectronULA installed into the Electron")

Switch on and hope it goes 'beep' :)

# Troubleshooting

Ah, so it didn't go 'beep', sorry :(

Here are some things you can check for:

- Sometimes the Elk doesn't come up correctly on power-up first time, try using Ctrl + Break or it off and on again
- You did plug in the Speaker and Video cables and check the monitor/TV was tuned and working, right? :)
- Check voltages on the board using a multimeter - are you seeing a nice 5V, 3.3V and 1.2V on the board when powered up?
- Taking it out and re-programming it - check that it says it verified after writing. If not, check the programmer is wired correctly.
- Check the pins are making a good connection in the socket - I check the top of each interrconnecting header pin with the leg of the component on the mainboard is showing continuity. Use the Schematic here and the Electron Schematics to see what pin of the interrconnects go where.
- Double check for solder bridges and poorly connected pins on the FPGA and Level Shiter ICs. Prod them under a microscope and look for movement and test continuity with adjacent pins (nice sharp multimeter probes are really helpful for this).
- If you have a scope you can check that the FPGA is reading the SPI ROM on start-up (probe the CIPO pin 5 on the config header pin, is it showing a burst of activity on power up). If not the FPGA may be stuck in PoR (missing one of it's voltages) or the SPI ROM chip is not connected properly.
- Usual troubleshooting now applies... Time to get the scope out and check: Elks PoR signal, 16MHz Oscillator, CPU Reset, Phi0, ROM enable, Address lines, Data lines, DRAM CAS/RAS, DRAM Address lines, DRAM Data lines, etc... See anything weird? Check the FPGA board soldering or socket connections to those signals using the schematic. Maybe the Elk Motherboard needs some work too (ie, needs a good Power on Reset signal and 16MHz clock), maybe you have a you have a bad 16MHz Crystal, 6502, DRAM, ROM, etc..? I have a basic diag ROM called the [ElkWSS-DiagROM](https://github.com/moogway82/ElkWSS-DiagROM) which might help see if PoR, CPU and DRAM is working ok...
- Get in touch via the [Stardot forums](https://stardot.org.uk/forums/index.php), I might be able to help or others might have some ideas what's going wrong...

# Acknowledgements

Big thanks to the following people for their support, inspiration and feedback:

- ScurvyGeek on Twitter who alerted me to the Electron joblot I got my poorly machine from, and for telling me that a missing ULA was not the end for it...
- David Banks (aka hoglet) for his ElectronFpga VHDL which is the codebase I started from
- Myelin's UltimateElectronULA board which was a useful reference to some of the hardware interfacing issues
- Gary Preston (aka Hicks) who's [Blog](https://www.mups.co.uk/project/hardware/acorn_electron/) and code was super helpful to understanding the Electron better
- Budgie for showing me that a simplier FPGA ULA project was possible and something I might manage
- Eric Schlaepfer (aka TubeTime) for the Graphics Gremlin project which gave me an inexpensive, Open-Source, 5V tollerant FPGA project to form the base of my hardware design
- Dave Hitchins for being really supportive to me from early on and sharing his knowledge and Electron hardware for me to test against
- Gary Colville (aka ramtop) for his support and providing access to his amazing ElkSD which sped up testing considerably
- Julian, a volunteer at the RMC Retro Cave who was really supportive and gave me a much needed boost to carry on when it wasn't going well
- The Stardot community - great group of people and just an amazing place for all things Acorn
- MFMI Lee and his Discord Server for just being a super supportive community and giving me the push to get this out there
- Libi, my amazing partner for putting up with me mucking about on old computers


# Lisence

The HDL source code, all files under 'HDL' folder and sub-folders, is derived from [Dave Banks, hoglet ElectronFpga project](https://github.com/hoglet67/ElectronFpga) licenced under GPL v3. 

Board design, all files under 'Hardware' folder and sub-folders, is derived from [Tube Time, schlae Graphics Gremlin project](https://github.com/schlae/graphics-gremlin) and licenced under a [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/). 
