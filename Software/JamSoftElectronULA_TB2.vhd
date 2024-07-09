library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JamSoftElectronULA_TB2 is
  generic (
    run_sound_out_test  : boolean := false;
    run_rgb_test        : boolean := true;
    rgb_test_quick      : boolean := false;
    run_turbo_mode      : boolean := true;
    run_ram_test        : boolean := true;
    ram_test_quick      : boolean := false; -- Quick RAM Test uses only sequencial write pattern
    run_rom_test        : boolean := false;
    run_int_test        : boolean := false;
    run_caps_test       : boolean := false;
    run_phi_test        : boolean := false;
    run_sync_ram_slot   : boolean := true;
    run_paging_test     : boolean := true
  );
end;

architecture behavioral of JamSoftElectronULA_TB2 is
  signal clk_16M00, R_W_n, data_en_n, RST_IN_n, RST_OUT_n, IRQ_n, ROM_n, red, green, blue, csync, HS_n, sound, casIn, casOut, caps, motor, cpu_clk_out, testing_pin : std_logic;
  -- signal NMI_n : std_logic;
  signal addr : std_logic_vector(15 downto 0);
  -- signal data_in, data_out : std_logic_vector(7 downto 0);
  signal data : std_logic_vector(7 downto 0);
  signal kbd : std_logic_vector(3 downto 0);
  -- New RAM Signals:
  signal dram_data : std_logic_vector(3 downto 0);
  signal dram_addr : std_logic_vector(7 downto 0);
  signal ras_n     : std_logic;
  signal cas_n     : std_logic;
  signal ram_we    : std_logic;
  signal ram_nRW    : std_logic;

  constant c_clk_period : time := 1 us / 16.0; -- MHz
  constant cpu_addr_ready : time := 125 ns; -- Time for the 6502 to have the address lines ready after PHI0 falling edge
begin

  ula : entity work.JamSoftElectronULA 
  port map(
    clk_16M00 => clk_16M00,
    addr => addr,
    data => data,
    R_W_n => R_W_n,
    data_en_n => data_en_n,
    -- POR_n => POR_n,
    RST_IN_n => RST_IN_n,
    RST_OUT_n => RST_OUT_n,
    IRQ_n => IRQ_n,
 --   NMI_n => NMI_n,
    -- New RAM signals
    dram_data => dram_data,
    dram_addr => dram_addr,
    ras_n => ras_n,
    cas_n => cas_n,
    ram_we => ram_we,
    ram_nRW => ram_nRW,

    ROM_n => ROM_n,
    red => red,
    green => green,
    blue => blue,
    csync => csync,
    HS_n  => HS_n,  -- TODO is this unused?
    sound => sound,
    kbd => kbd,
    casIn => casIn,
    casOut => casOut,
    caps => caps,
    motor => motor,
    cpu_clk_out => cpu_clk_out,
    testing_pin => testing_pin
  );

  RST_IN_n <= RST_OUT_n;

  --ram1 : entity work.dram_64k_w4 
  --port map(
  --  address => dram_addr,                     --: in std_logic_vector(7 downto 0);
  --  data => dram_data,                     --: out std_logic_vector(3 downto 0);
  --  WE => ram_we,                     --: in std_logic;
  --  RAS => ras_n,                    --: in std_logic;
  --  CAS => cas_n                    --: in std_logic
  --);

  ram1 : entity work.TM4164EA3_64k_W4 
  port map(
    i_addr => dram_addr,                     --: in std_logic_vector(7 downto 0);
    data => dram_data,                     --: out std_logic_vector(3 downto 0);
    i_n_we => ram_we,                     --: in std_logic;
    i_n_ras => ras_n,                    --: in std_logic;
    i_n_cas => cas_n,                    --: in std_logic
    i_clk => clk_16M00
  );


  p_clk_gen : process begin
    wait for c_clk_period / 2;
    clk_16M00 <= '1';
    wait for c_clk_period / 2;
    clk_16M00 <= '0';
  end process;

  tb : process 
    variable rgb_test_vram_addr : std_logic_vector(15 downto 0) := x"3000";
    variable ram_test_size : integer := 12287; -- = Up to address 0x2FFF, 12k
    variable rgb_test_size : integer := 20478; -- = 0x3000 to 0x7FFF, 20k
  begin

  -- What's the bare minimum signals to get the clock working, what if we set nothing?
  if run_phi_test = true then

    -- Nothing but OSC
    --wait for 20 us;
    -- What if POR is just held high?
    -- POR_n <= '1';
    -- wait for 10 us;
    -- Commented out the 16MHz CLK gen, what now?
    --POR_n <= '1';
    --wait for  20 us;
    --POR_n <= '1';
    --wait for  200 us;
    --RST_IN_n <= '0';
    --wait for 50 us;

  end if;

    -- wait until falling_edge(clk_16M00);
    --POR_n <= '0';
    --wait for  10 us;
    --POR_n <= '1';
    -- simulate CPU Reset read from 0xFFFC & 0xFFFD
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FFFC";
    --data <= (others => 'Z');
    --R_W_n <= '1';

    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FFFD";
    --data <= (others => 'Z');
    --R_W_n <= '1';

    wait until RST_OUT_n = '1';

    -- Check the PoR bit from the ISR
    wait until falling_edge(cpu_clk_out);
    -- wait for cpu_addr_ready;
    addr <= x"FE00";
    data <= (others => 'Z');
    R_W_n <= '1';
    assert data(1) = '0' report "PoR Bit should be 1 on first boot" severity error;

    -- Read something else
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE01";
    data <= (others => 'Z');
    R_W_n <= '1';
    

    -- Check the PoR bit again from the ISR
    wait until falling_edge(cpu_clk_out);
    -- wait for cpu_addr_ready;
    addr <= x"FE00";
    data <= (others => 'Z');
    R_W_n <= '1';
    assert data(1) = '1' report "PoR Bit should be 0 on next read" severity error;



  if run_sound_out_test = true then 

    -----------------------
    -- 1. Sound Output Test
    -----------------------
    -- Write note to &FE06 : Sound frequency = 1 MHz / [16 * (S + 1)]
    -- Write to &FE07 bits 1 & 2 to 01 to enable sound
    -- See if the Sounds Out pin oscilates at correct freq

    -- 02 = 15.625kHz Actually period of 64 us, not sure equation above it correct as 1MHz / (16 * (2+1)) = 1MHz / (16 * (3)) = 1MHz / 48 = 20.83kHz
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE06";
    data <= x"02"; 
    R_W_n <= '0';

    -- Sound on (on at reset by default)
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07";
    data <= "00000010"; -- Sound On
    R_W_n <= '0';

    wait for 100 us; 

    -- Highest frequency 31.25kHz, 00 alternates sound every clock, at 16MHz! 
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE06";
    data <= x"01"; 
    R_W_n <= '0';

    wait for 100 us; 

    -- Sound off
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07";
    data <= "00000000"; 
    R_W_n <= '0';
    wait for 100 us;

    -- Bus null
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"C000";
    data <= x"00"; 
    R_W_n <= '1';

  end if;

  if run_turbo_mode = true then

    -------------------------------
    -- 9. Keyboard & Turbo Test
    -------------------------------
    -- Keyboard page 8 & 9 (1000 & 1001)
    -- Page in ROM 8 (keyboard)
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001000";
    R_W_n <= '0';
    -- Caps Lk + Ctrl read &9FFF
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"9FFF";
    data <= (others => 'Z');
    R_W_n <= '1';
    kbd <= "1001";
    -- Number 2
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"B7FF";
    data <= (others => 'Z');
    R_W_n <= '1';
    kbd <= "1110";
    -- Is turbo on?
    -- Put BASIC back in and run RAM test...
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001010"; -- ROM no. 10
    R_W_n <= '0';

  end if;

  if run_rgb_test = true then 

    -----------------------
    -- 2. RGB Test
    -----------------------
    -- Set video mode to mode 2 in FE07 register
    -- Set palettes all 16 colours to FE08 to FE0F
    -- Fill vram with cycling pattern 3000 to 7FFF
    -- Check RGB values on output waves or assert in a loop

    -- Set video mode to mode 2
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07";
    data <= "00010000"; 
    R_W_n <= '0';

    -- Set colour palettes
    -- All 8 colour options
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE08";
    data <= "01110100"; -- B10 B8 B2 B0 G10 G8 X X
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE09";
    data <= "00010111";  -- X X G2 G0 R10 R8 R2 R0
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE0A";
    data <= "00110100"; -- B14 B12 B6 B4 G14 G12 X X
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE0B";
    data <= "00011000"; -- X X G6 G4 R14 R12 R6 R4
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE0C";
    data <= "00000000"; -- B15 B13 B7 B5 G15 G13 X X
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE0D";
    data <= "00010000"; -- X X G7 G5 R15 R13 R7 R5
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE0E";
    data <= "01000100"; -- B11 B9 B3 B1 G11 G9 X X
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE0F";
    data <= "10010111"; -- X X G3 G1 R11 R9 R3 R1
    R_W_n <= '0';

    if rgb_test_quick then
      rgb_test_size := 1024; -- 0x3000 to 0x3400 1k
    end if;

    -- Fill VRAM with consecutive bytes
    for i in 0 to rgb_test_size loop
      wait until falling_edge(cpu_clk_out);
      wait for cpu_addr_ready;
      rgb_test_vram_addr := std_logic_vector(unsigned(rgb_test_vram_addr) + 1);
      addr <= rgb_test_vram_addr;
      data <=  rgb_test_vram_addr(7 downto 0);
      R_W_n <= '0';
    end loop;
    wait for 10 us;

    -- Set colour palette - all off
    -- Set colour palettes
    -- All 8 colour options
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE08";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE09";
    --data <= "11111111";  
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0A";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0B";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0C";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0D";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0E";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0F";
    --data <= "11111111"; 
    --R_W_n <= '0';
    --wait for 10 us;

    ---- Set colour palette - all on
    ---- Set colour palettes
    ---- All 8 colour options
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE08";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE09";
    --data <= "00000000";  
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0A";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0B";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0C";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0D";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0E";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait until falling_edge(cpu_clk_out);
    --wait for cpu_addr_ready;
    --addr <= x"FE0F";
    --data <= "00000000"; 
    --R_W_n <= '0';
    --wait for 10 us;

  end if;

 

  if run_ram_test = true then

  if ram_test_quick = true then
    ram_test_size := 1024; -- Up to address 0x400 (1k)
  else 
    ram_test_size := 32767; -- Full 32k
  end if;

    -------------------------------
    -- 3. RAM Signals and Data Test
    -------------------------------
    -- Ram: Like the pc bios test, in a loop write to every user, non video ram address and read it all back asserting 
    -- that each read byte is the same as the one written. 00001111 then 11110000 is what Sergeys BIOS did I think. 
    -- Video ram is Lisa tested with RGB out so not bothered
    -- Lets just test &0000 to &2FFF as there is no CPU to worry about zero page, vectors and no ROM for OS vars...
    -- RAM Addr: ROW should be the LSB of the address line for every ram address (combine with data out ram test). Col 1st nibble 
    -- and col 2nd nibble should be whatever system I decide for that (copy Gary's?) 0 or 1 added to MSBs of address.
    -- RAM Data: Combine with data out ram test and check to see that the pattern coming out is the same as the nibbles on the data bus. 


    -- Set Video mode to 110 to speed things up a bit
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07";
    data <= "00110000"; 
    R_W_n <= '0';

    -- Write bytes
    rgb_test_vram_addr := x"0000";
    for i in 0 to ram_test_size loop
      wait until falling_edge(cpu_clk_out);
      wait for cpu_addr_ready;
      addr <= rgb_test_vram_addr;
      --data <=  x"5A";
      data <= rgb_test_vram_addr(7 downto 0);
      R_W_n <= '0';
      rgb_test_vram_addr := std_logic_vector(unsigned(rgb_test_vram_addr) + 1);
      -- wait till RAS low
      -- Check that DRAM ADDR (ROW) is LSB of ADDR
      -- Wait till CAS low
      -- Check that DRAM ADDR (COL1) is MSB +0/1 of ADDR 
      -- Check DRAM DATA is 5/A
      -- Wait till CAS low
      -- Check that DRAM ADDR (COL2) is MSB +0/1 of ADDR 
      -- Check DRAM DATA is 5/A
    end loop;

    -- Read back bytes
    -- todo: Timing here is all wrong, needs re-writing - it never tests addr 0000 and I need it to read data_out on falling edge...
    rgb_test_vram_addr := x"0000";
    wait until falling_edge(cpu_clk_out);
    for i in 0 to ram_test_size loop
      wait for cpu_addr_ready;
      addr <= rgb_test_vram_addr;
      R_W_n <= '1';
      data <= (others => 'Z');
      wait until falling_edge(cpu_clk_out);
      --assert data = x"5A" report "Data not valid at addr: " & INTEGER'IMAGE(to_integer(unsigned(addr))) severity error;
      assert data = rgb_test_vram_addr(7 downto 0) report "Data not valid at addr: " & INTEGER'IMAGE(to_integer(unsigned(addr))) severity error;
      rgb_test_vram_addr := std_logic_vector(unsigned(rgb_test_vram_addr) + 1);
    end loop;

  if ram_test_quick = false then

    -- Write bytes
    rgb_test_vram_addr := x"0000";
    for i in 0 to ram_test_size loop
      wait until falling_edge(cpu_clk_out);
      wait for cpu_addr_ready;
      addr <= rgb_test_vram_addr;
      data <=  x"A5";
      --data <= rgb_test_vram_addr(7 downto 0);
      R_W_n <= '0';
      rgb_test_vram_addr := std_logic_vector(unsigned(rgb_test_vram_addr) + 1);
    end loop;

    -- Read back bytes
    rgb_test_vram_addr := x"0000";
    wait until falling_edge(cpu_clk_out);
    for i in 0 to ram_test_size loop
      wait for cpu_addr_ready;
      addr <= rgb_test_vram_addr;
      R_W_n <= '1';
      data <= (others => 'Z');
      wait until falling_edge(cpu_clk_out);
      assert data = x"A5" report "Data not valid at addr: " & INTEGER'IMAGE(to_integer(unsigned(addr))) severity error;
      --assert data = rgb_test_vram_addr(7 downto 0) report "Data not valid at addr: " & INTEGER'IMAGE(to_integer(unsigned(addr))) severity error;
      rgb_test_vram_addr := std_logic_vector(unsigned(rgb_test_vram_addr) + 1);
    end loop;

  end if; -- ram_test_quick

  end if; -- run_ram_test

  if run_rom_test = true then

    -------------------------------
    -- 4. ROM CS
    -------------------------------
    -- Assert a ROM address and see if this goes low. Try writing and see what happens!

    -- 1st ROM address
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"C000";
    R_W_n <= '1';
    wait for 1 ns;
    assert ROM_n = '0' report "ROM_n not set LOW on first ROM address" severity error;
    assert data_en_n = '1' report "ULA Data Bus Buffer Enable not set HIGH on first ROM address" severity error;

    -- Last ROM addr
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFFF";
    R_W_n <= '1';
    wait for 1 ns;
    assert ROM_n = '0' report "ROM_n not set LOW on last ROM address" severity error;
    assert data_en_n = '1' report "ULA Data Bus Buffer Enable not set HIGH on last ROM address" severity error;


    -- Read RAM sets ROM_n high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"1000";
    R_W_n <= '1';
    wait for 1 ns;
    assert ROM_n = '1' report "ROM_n not set HIGH on RAM address" severity error;
    assert data_en_n = '0' report "ULA Data Bus Buffer Enable not set LOQ on RAM address" severity error;


  end if;

  if run_int_test = true then

    -------------------------------
    -- 5. Interrupts
    -------------------------------
    -- Un-mask the RTC interrupt (every 20ms) and see if it fires
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE00";
    data <= "00001001";
    R_W_n <= '0';
    wait for 20 ms;
    assert IRQ_n = '0' report "IRQ_n didn't go LOW after RTC interrupt was unmasked." severity error;

    -- Clear the RTC interrupt
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00100000";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for 1 ns;
    assert IRQ_n = '1' report "IRQ_n didn't go back to HGIH after RTC interrupt reset." severity error;

    -- Re-mask the RTC interrupt (every 20ms) and check it doesn't fire
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE00";
    data <= "00000001";
    R_W_n <= '0';
    wait for 20 ms;
    assert IRQ_n = '1' report "IRQ_n didn't stay HIGH after RTC interrupt was re-masked." severity error;

  end if;

  if run_caps_test = true then

    -------------------------------
    -- 6. Caps lock
    -------------------------------
    -- Just write the caps on bit of misc reg and see if this goes on or off
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07";
    data <= "10110000";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    assert caps = '1' report "caps didn't go HIGH after Caps bit set in FE07." severity error;

  end if;

  if run_sync_ram_slot = true then

    -------------------------------
    -- 7. 2Mhz to 1Mhz Transition
    -------------------------------

    -- set to mode 100 (4?) GFX mode, no contension
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07"; -- b7=caps int, b6=motor, b5-3 gfx, b2-1 comms mode, b0?
    data <= "00100000";
    R_W_n <= '0';

    -- Write some data to test RAM Reads
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D02"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= x"51";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D03"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= x"52";
    R_W_n <= '0';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFF0"; -- ROM read, sets up 2MHz - DRAM VID slot
    data <= (others => 'Z');
    R_W_n <= '1';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFF1"; -- ROM read, sets up 2MHz - DRAM CPU slot
    data <= (others => 'Z');
    R_W_n <= '1';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFF2"; -- ROM read, sets up 2MHz - DRAM CPU slot
    data <= (others => 'Z');
    R_W_n <= '1';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D00"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= x"51";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D01"; -- RAM write, sets back to 1MHz - DRAM VID slot, back in sync?
    data <= x"52";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFF3"; -- ROM read, sets up 2MHz - DRAM CPU slot
    data <= (others => 'Z');
    R_W_n <= '1';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D02"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D03"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    -- Can I read from a register?
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE00"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    -- Read from another RAM location
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"0D00"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    -- Read from screen addresses with corruptions
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E00"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E01"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E02"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E03"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E04"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E05"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E06"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"7E07"; -- RAM write, sets back to 1MHz - DRAM VID slot, out of sync
    data <= (others => 'Z');
    R_W_n <= '1';

  end if;

  if run_paging_test = true then


    -------------------------------
    -- 8. ROM Paging Test
    -------------------------------

    -- Page in ROM 15
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001111";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should be high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '0' report "ROM_n shouldn't go low as ROM 15 should be paged in." severity error;
    -- Now read a MOS address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"C001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should be low as MOS is being read." severity error;

    -- Page in ROM 14
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001110";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should be high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '0' report "ROM_n shouldn't go low as ROM 14 should be paged in." severity error;
    -- Now read a MOS address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"C001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should be low as MOS is being read." severity error;

    -- Page in ROM 13
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= x"0D";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should be high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '0' report "ROM_n shouldn't go low as ROM 13 should be paged in." severity error;
    -- Now read a MOS address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"C001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should be low as MOS is being read." severity error;

    -- Page in ROM 12
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= x"0C";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should be high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '0' report "ROM_n shouldn't go low as ROM 13 should be paged in." severity error;
    -- Now read a MOS address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"C001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should be low as MOS is being read." severity error;

    -- Page BASIC back in (ROM 10)
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001010";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should go low as BASIC should be paged back in." severity error;
    -- Page BASIC back in using ROM 11
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001011";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should go low as BASIC should be paged back in." severity error;
    -- Page ROM 12 in
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001100";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should be high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '0' report "ROM_n shouldn't go low as ROM 12 should be paged in." severity error;
    -- Page ROM 1 in
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00000001";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should be high
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '0' report "ROM_n shouldn't go low as ROM 1 should be paged in." severity error;
    -- Page BASIC back in
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= "00001010";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should go LOW
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should go low as BASIC should be paged back in." severity error;

    -- Try to Page ROM 7 in
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE05";
    data <= x"07";
    R_W_n <= '0';
    -- Now read a BASIC address - ROM_n should go low
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"8001";
    data <= (others => 'Z');
    R_W_n <= '0';
    assert ROM_n = '1' report "ROM_n should go low as BASIC should still be paged in." severity error;

  end if;


  

    wait until falling_edge(cpu_clk_out);
    wait until falling_edge(cpu_clk_out);
    wait until falling_edge(cpu_clk_out);
    assert false report "End of testing, phew!" severity failure;
    wait;
  end process;


end;