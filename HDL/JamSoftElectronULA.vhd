--------------------------------------------------------------------------------
-- Copyright (c) 2020 David Banks, 2023 Chris Jamieson
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : JamSoftElectronULA.vhd
-- /___/   /\     Timestamp : 08/05/2023
-- \   \  /  \
--  \___\/\___\
--
--Design Name: ElectronULA

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JamSoftElectronULA is
    port (
        clk_16M00 : in  std_logic;

        -- CPU Interface
        addr      : in  std_logic_vector(15 downto 0);
        data      : inout std_logic_vector(7 downto 0);  -- Async, but stable on rising edge of cpu_clken
        R_W_n     : in  std_logic;
        data_en_n : out std_logic; -- Remove ULA from Data bus when it's not being read from (ie, CPU is talking to ROM)


        POR_n     : in std_logic;
        -- Can't easily translate the open-collector RST_in 'inout' between 5V and 3V domains, so changing to RST IN and OUT with
        -- circuitry used in other ULA replacement projects.
        RST_IN_n  : in std_logic;
        RST_OUT_n : out std_logic;
        IRQ_n     : out std_logic;
        -- NMI_n     : in  std_logic; -- Does nothing, but it should give Memory to the CPU regardless of Mode...

        -- RAM Interface
        dram_data : inout std_logic_vector(3 downto 0);
        dram_addr : out std_logic_vector(7 downto 0);
        ras_n     : out std_logic;
        cas_n     : out std_logic;
        ram_we    : out std_logic;
        ram_nRW   : out std_logic; -- For the DRAM buffer direction, needs to be opposite of the ram_we signal...


        -- Rom Enable
        ROM_n     : out std_logic;

        -- Video
        red       : out std_logic;
        green     : out std_logic;
        blue      : out std_logic;
        -- No VSync
        csync     : out std_logic;
        -- Currently unused
        HS_n      : out std_logic := '1';

        -- Audio
        sound     : out std_logic;

        -- Keyboard
        kbd       : in  std_logic_vector(3 downto 0);  -- Async

        -- Casette
        casIn     : in  std_logic;
        casOut    : out std_logic;

        -- MISC
        caps      : out std_logic;
        motor     : out std_logic;

        -- Clock Generation
        cpu_clk_out    : out std_logic;

        -- TEST Signal
        testing_pin    : out std_logic

      );
end;

architecture behavioral of JamSoftElectronULA is

  signal hsync_int      : std_logic;
  signal hsync_int_last : std_logic;
  signal vsync_int      : std_logic;

  -- ram_data holds the RAM data to put out on data_out...
  signal ram_data       : std_logic_vector(7 downto 0);
  signal block_ram_data : std_logic_vector(7 downto 0);
  signal ram_addr       : std_logic_vector(14 downto 0);
  -- Internal Data bus
  signal data_en        : std_logic;
  signal data_in        : std_logic_vector(7 downto 0);  -- Async, but stable on rising edge of cpu_clken
  signal data_out       : std_logic_vector(7 downto 0);

  signal master_irq     : std_logic;

  signal power_on_reset : std_logic; -- := '1';

  signal delayed_clear_reset : std_logic_vector(3 downto 0); -- := '0';

  signal general_counter: std_logic_vector(15 downto 0);
  signal sound_bit      : std_logic;
  signal isr_data       : std_logic_vector(7 downto 0);

  -- ULA Registers
  signal isr            : std_logic_vector(6 downto 2);
  signal ier            : std_logic_vector(6 downto 2);
  signal screen_base    : std_logic_vector(14 downto 6);
  signal data_shift     : std_logic_vector(7 downto 0);
  signal page_enable    : std_logic;
  signal page           : std_logic_vector(2 downto 0);
  signal counter        : std_logic_vector(7 downto 0);
  signal comms_mode     : std_logic_vector(1 downto 0);

  type palette_type is array (0 to 7) of std_logic_vector (7 downto 0);
  signal palette        : palette_type;

  constant hsync_start    : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(768, 11));
  constant hsync_end      : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(832, 11));
  constant h_active       : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(640, 11));
  constant h_total        : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(1023, 11));
  constant h_reset_addr   : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(1016, 11));
  signal h_count        : std_logic_vector(10 downto 0);
  signal resync_h_count : std_logic;

  constant vsync_start  : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(274, 10));
  signal vsync_end      : std_logic_vector(9 downto 0);
  constant v_active_gph   : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(256, 10));
  constant v_active_txt   : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(250, 10));
  signal v_total        : std_logic_vector(9 downto 0);
  signal v_count        : std_logic_vector(9 downto 0);

  constant v_rtc          : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned( 99, 10));
  constant v_disp_gph     : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(255, 10));
  constant v_disp_txt     : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(249, 10));

  signal char_row       : std_logic_vector(3 downto 0);

  signal screen_addr    : std_logic_vector(14 downto 0);
  signal screen_data    : std_logic_vector(7 downto 0);

  -- DEBUGGING screen address variables
  -- signal pixel_debug : std_logic_vector(3 downto 0);
  -- start address of current row block (8-10 lines)
  -- signal row_addr_debug  : std_logic_vector(14 downto 6);
  -- address within current line
  -- signal byte_addr_debug : std_logic_vector(14 downto 3);

  -- Screen Mode Registers

  -- bits 6..3 the of the 256 byte page that the mode starts at
  signal mode_base      : std_logic_vector(6 downto 3);

  -- the number of bits per pixel (0 = 1BPP, 1 = 2BPP, 2=4BPP)
  signal mode_bpp       : std_logic_vector(1 downto 0);

   -- a '1' indicates a text mode (modes 3 and 6)
  signal mode_text      : std_logic;

  -- a '1' indicates a 40-col mode (modes 4, 5 and 6)
  signal mode_40        : std_logic;

  signal last_line      : std_logic;

  signal display_intr   : std_logic;
  signal display_intr1  : std_logic;
  signal display_intr2  : std_logic;

  signal rtc_intr       : std_logic;
  signal rtc_intr1      : std_logic;
  signal rtc_intr2      : std_logic;

  signal ctrl_caps      : std_logic;
  signal turbo          : std_logic;

  signal field          : std_logic;

  signal caps_int       : std_logic;
  signal motor_int      : std_logic;

  -- Tape Interface
  signal cintone        : std_logic;
  signal cindat         : std_logic;
  signal cinbits        : std_logic_vector(3 downto 0);
  signal coutbits       : std_logic_vector(3 downto 0);
  signal casIn1         : std_logic;
  signal casIn2         : std_logic;
  signal casIn3         : std_logic;
  signal ignore_next    : std_logic;

  -- internal RGB signals before final mux
  signal red_int        : std_logic;
  signal green_int      : std_logic;
  signal blue_int       : std_logic;

  signal ROM_n_int      :   std_logic;


  -- clock enable generation
  signal clken_counter  : std_logic_vector (3 downto 0); -- := (others => '0');

  signal contention     : std_logic;
  signal io_access      : std_logic; -- always at 1MHz, no contention
  signal ram_access     : std_logic; -- 1MHz/2MHz/Stopped
  signal turbo_ram_access     : std_logic; -- 1MHz/2MHz/Stopped
  signal turbo_we       : std_logic;

  signal kbd_access     : std_logic;

  signal clk_stopped    : std_logic;

  signal cpu_clken      : std_logic;
  signal cpu_clk        : std_logic; -- := '1';
  signal not_cpu_clk    : std_logic;
  signal clk_counter    : std_logic_vector(2 downto 0); -- := (others => '0');
  signal por_cpu_rst_counter : std_logic_vector (7 downto 0); -- Counter to reset the CPU after power on

  signal ula_irq_n         : std_logic;

  -- DRAM Signals
  signal cpu_ram_slot : std_logic; 
  signal dram_we_int   : std_logic;
  signal dram_clk_phase : std_logic_vector(2 downto 0);
  signal dram_data_latch : std_logic_vector(3 downto 0);
  signal dram_data_in, dram_data_out : std_logic_vector(3 downto 0);
  signal dram_ras_int : std_logic;
  signal dram_cas1_int, dram_cas1_int_delay : std_logic;
  signal dram_cas2_int : std_logic;
  signal dram_ldcol1, dram_ldcol2, dram_ldext : std_logic; -- Latch COL1 Nibble, COL2 Nibble and time latch to Screen/CPU
  signal dram_addr_sel : std_logic_vector(1 downto 0); -- 00 LSB, 01 MSB-N1, 10 MSB-N2, 11 HiZ

  -- DRAM Controller FSM States
  type dramc_fsm_type is (RESET, ROW_LATCH, COL1_LATCH, COL1_READ, COL1_RESET, COL2_LATCH, COL2_READ, ROWCOL2_RESET, EXTLATCH_RESET);
  signal DRAMC_PS, DRAMC_NS : dramc_fsm_type;
  --signal DRAMC_PS_DEBUG, DRAMC_NS_DEBUG : std_logic_vector(3 downto 0);

-- Helper function to cast an std_logic value to an integer
function sl2int (x: std_logic) return integer is
begin
    if x = '1' then
        return 1;
    else
        return 0;
    end if;
end;

-- Helper function to cast an std_logic_vector value to an integer
function slv2int (x: std_logic_vector) return integer is
begin
    return to_integer(unsigned(x));
end;

begin

    -- Turbo_RAM write enable 
    turbo_we <= not R_W_n when addr(15 downto 12) = x"1" or addr(15 downto 12) = x"0"  else --Inverted '1' for write, '0' for Read
                '0'; -- Otherwise Read

    not_cpu_clk <= not cpu_clk;

    -- Turbo RAM using 8K Block RAM on FPGA
    ula : entity work.turbo_ram 
    port map(
        addr => addr(12 downto 0),
        write_en => turbo_we,
        wclk => not_cpu_clk,
        rclk => cpu_clk,
        din => data_in,
        dout => block_ram_data
    );

    -- TESTING PIN - This will change depending on what I need to check
    testing_pin <= '0';
        

    -- I'm only using mode 01 from the ElectronFpga project as it's original Electron video timing constants
    -- mode 00 - RGB/s @ 50Hz non-interlaced
    -- mode 01 - RGB/s @ 50Hz interlaced
    -- mode 10 - SVGA  @ 50Hz
    -- mode 11 - SVGA  @ 60Hz

    -- Reset is open collector to avoid contention when BREAK pressed
    -- RST_OUT_n <= '0' when POR_n = '0' else '1';
    -- CPU needs a clock whilst in reset is held, so lets try and give the CPU at least 16 clock ticks before reset is
    -- pulled high following PoR going high.
    por_delay_cpu_rst : process (clk_16M00, POR_n)
    begin

      if(POR_n = '0') then

        por_cpu_rst_counter <= (others => '0');
        RST_OUT_n <= '0';

      elsif rising_edge(clk_16M00) then

        if not (por_cpu_rst_counter = x"FF") then -- 1MHz clock would be 16 OSC pulses, so 16 of them is 256 = 0xFF
          por_cpu_rst_counter <= std_logic_vector(unsigned(por_cpu_rst_counter) + 1);
        else
          RST_OUT_n <= '1';
        end if;

      end if;
        
    end process;

    sound <= sound_bit;

    -- The external ROM is enabled:
    -- - When the address is C000-FBFF and FF00-FFFF (i.e. OS Rom)
    -- - When the address is 8000-BFFF and the ROM 10 or 11 is paged in (101x)

    -- FE05: ----EPPP
    -- E = ROM Page Enable (bit 3), also acts as the MSB for the ROM Slots below
    -- PPP = ROM Paging Bits (bits 2,1,0)

    -- ROM Slots:
    -- 15 - Free
    -- 14 - Free
    -- 13 - Free
    -- 12 - Free
    -- 11 - BASIC (both 11 and 10 are the same)
    -- 10 - BASIC
    -- 9  - Keyb (both 9 and 8 are the same)
    -- 8  - Keyb
    -- 7-0 - Free : To access these you need to page in any 12-15 first which then allows 0-7 to be selected - I don't know why

    ROM_n_int <= '0' when addr(15 downto 14) = "11" and io_access = '0' else
                 '0' when addr(15 downto 14) = "10" and page_enable = '1' and page(2 downto 1) = "01" else
                 '1';

    ROM_n <= ROM_n_int;

    -- ULA Reads + RAM Reads + KBD Reads
    data_out <= ram_data                  when ram_access = '1' else
                block_ram_data            when turbo_ram_access = '1' else
                "0000" & (kbd xor "1111") when kbd_access = '1' else
                isr_data                  when addr(15 downto 8) = x"FE" and addr(3 downto 0) = x"0" else
                data_shift                when addr(15 downto 8) = x"FE" and addr(3 downto 0) = x"4" else
                x"F1"; -- todo FIXEME

    -- Used to control the ULA's data bus buffer (ie, Level Shifting buffer so FPGA can handle 5V)
    -- ULA isn't the only thing on the Databus, ROM talks directly to CPU & Keyboard as might other edge connected devices
    data_en  <= '1'                       when addr(15) = '0' else
                '1'                       when kbd_access = '1' else
                '1'                       when addr(15 downto 8) = x"FE" else
                '0';

    -- The data buffer enable is active LOW
    data_en_n <= not data_en;


    -- Bidirectional Data Bus control
    -- Write to Data but when CPU Read and data_en is met (see above - RAM/ROM or KYB)
    data <= data_out when R_W_n = '1' and data_en = '1' else 
            "ZZZZZZZZ";

    data_in <= data;

    -- Register FEx0 is the Interrupt Status Register (Read Only)
    -- Bit 7 always reads as 1
    -- Bits 6..2 refect in interrups status regs
    -- Bit 1 is the power up reset bit, cleared by the first read after power up
    -- Bit 0 is the OR of bits 6..2
    master_irq <= (isr(6) and ier(6)) or
                  (isr(5) and ier(5)) or
                  (isr(4) and ier(4)) or
                  (isr(3) and ier(3)) or
                  (isr(2) and ier(2));

    ula_irq_n  <= not master_irq;
    IRQ_n <= ula_irq_n;

    isr_data   <= '1' & isr(6 downto 2) & power_on_reset & master_irq;

    -- Split this out so PoR bit clearing to be clocked by cpu_en rising
    -- Waiting 1 or 2 cpu_clken ticks didn't seem to Hard Reset MOS on power up
    -- so gone to a silly number of 15 cpu_clken and it works, so leaving
    -- it instead of trying to hunt for an optimal.
    reset_por : process (cpu_clken, POR_n)
    begin
      if (POR_n = '0') then
          -- Sets initial values using the PoR signal
          power_on_reset <= '1';
          delayed_clear_reset <= x"0";

      elsif rising_edge(cpu_clken) then

        if (addr(15 downto 8) = x"FE") and (addr(3 downto 0) = x"0") and power_on_reset = '1' then
          delayed_clear_reset <= x"1";
        end if;

        if not(delayed_clear_reset = x"0") then
          if delayed_clear_reset = x"F" then
            power_on_reset <= '0';
          else
            delayed_clear_reset <= std_logic_vector(unsigned(delayed_clear_reset) + 1);
          end if;
        end if;

      end if;

    end process reset_por;

    int_cass_regs : process (clk_16M00)
    begin

        if rising_edge(clk_16M00) then

            if (RST_IN_n = '0') then

               isr             <= (others => '0');
               ier             <= (others => '0');
               screen_base     <= (others => '0');
               data_shift      <= (others => '0');
               page_enable     <= '0';
               page            <= (others => '0');
               counter         <= (others => '0');
               comms_mode      <= "01";
               motor_int       <= '0';
               caps_int        <= '0';
               general_counter <= (others => '0');
               sound_bit       <= '0';
               cindat          <= '0';
               cintone         <= '0';
               ctrl_caps       <= '0';
               turbo           <= '0';

            else
 
                -- Synchronize the display interrupt signal from the VGA clock domain
                display_intr1 <= display_intr;
                display_intr2 <= display_intr1;
                -- Generate the display end interrupt on the rising edge (line 256 of the screen)
                if (display_intr2 = '0' and display_intr1 = '1') then
                    isr(2) <= '1';
                end if;
                -- Synchronize the rtc interrupt signal from the VGA clock domain
                rtc_intr1 <= rtc_intr;
                rtc_intr2 <= rtc_intr1;

                -- Generate the rtc interrupt on the rising edge (line 100 of the screen)
                if (rtc_intr2 = '0' and rtc_intr1 = '1') then
                    isr(3) <= '1';
                end if;

                if (comms_mode = "00") then
                    -- Cassette In Mode
                    if (casIn2 = '0') then
                        general_counter <= (others => '0');
                    else
                        general_counter <= std_logic_vector(unsigned(general_counter) + 1);
                    end if;
                elsif (comms_mode = "01") then
                    -- Sound Mode - Frequency = 1MHz / [16 * (S + 1)]
                    if (general_counter = "0000000000000000") then
                        general_counter <= counter & "00000000";
                        sound_bit <= not sound_bit;
                    else
                        general_counter <= std_logic_vector(unsigned(general_counter) - 1);
                    end if;
                elsif (comms_mode = "10") then
                    -- Cassette Out Mode
                    -- Bit 12 is at 2404Hz
                    -- Bit 13 is at 1202Hz
                    if (general_counter(11 downto 0) = "000000000000") then
                        general_counter <= std_logic_vector(unsigned(general_counter) - x"301");
                    else
                        general_counter <= std_logic_vector(unsigned(general_counter) - x"001");
                    end if;
                end if;


                -- Tape Interface Receive
                casIn1 <= casIn;
                casIn2 <= casIn1;
                casIn3 <= casIn2;
                if (comms_mode = "00" and motor_int = '1') then
                    -- Only take actions on the falling edge of casIn
                    -- On the falling edge, general_counter will contain length of
                    -- the previous high pulse in 16MHz cycles.
                    -- A 1200Hz pulse is 6666 cycles
                    -- A 2400Hz pulse is 3333 cycles
                    -- A threshold in between would be 5000 cycles.
                    -- Ignore pulses shorter then say 500 cycles as these are
                    -- probably just noise.

                    if (casIn3 = '1' and casIn2 = '0' and unsigned(general_counter) > 500) then
                        -- a Pulse of length > 500 cycles has been detected

                        if (cindat = '0' and cintone = '0' and unsigned(general_counter) <= 5000) then
                            -- High Tone detected
                            cindat  <= '0';
                            cintone <= '1';
                            cinbits <= (others => '0');
                            -- Generate the high tone detect interrupt
                            isr(6) <= '1';

                        elsif (cindat = '0' and cintone = '1' and unsigned(general_counter) > 5000) then
                            -- Start bit detected
                            cindat  <= '1';
                            cintone <= '0';
                            cinbits <= (others => '0');

                        elsif (cindat = '1' and ignore_next = '1') then
                            -- Ignoring the second pulse in a bit at 2400Hz
                            ignore_next <= '0';

                        elsif (cindat = '1' and unsigned(cinbits) < 9) then

                            if (unsigned(cinbits) < 8) then
                                if (unsigned(general_counter) > 5000) then
                                    -- shift in a zero
                                    data_shift <= '0' & data_shift(7 downto 1);
                                else
                                    -- shift in a one
                                    data_shift <= '1' & data_shift(7 downto 1);
                                end if;
                                -- Generate the receive data int as soon as the
                                -- last bit has been shifted in.
                                if (cinbits = x"7") then
                                    isr(4) <= '1';
                                end if;
                            end if;
                            -- Ignore the second pulse in a bit at 2400Hz
                            if (unsigned(general_counter) > 5000) then
                                ignore_next <= '0';
                            else
                                ignore_next <= '1';
                            end if;
                            -- Move on to the next data bit
                            cinbits <= std_logic_vector(unsigned(cinbits) + 1);
                        elsif (cindat = '1' and cinbits = x"9") then
                            if (unsigned(general_counter) > 5000) then
                                -- Found next start bit...
                                cindat  <= '1';
                                cintone <= '0';
                                cinbits <= (others => '0');
                            else
                                -- Back in tone again
                                cindat  <= '0';
                                cintone <= '1';
                                cinbits <= (others => '0');
                                -- Generate the high tone detect interrupt
                                isr(6) <= '1';
                           end if;
                       end if;
                    end if;
                else
                    cindat      <= '0';
                    cintone     <= '0';
                    cinbits     <= (others => '0');
                    ignore_next <= '0';
                end if;

                -- regardless of the comms mode, update coutbits state (at 1200Hz)
                if general_counter(13 downto 0) = "00000000000000" then
                    -- wait to TDEmpty interrupt to be cleared before starting
                    if coutbits = x"0" then
                        if isr(5) = '0' then
                            coutbits <= x"9";
                        end if;
                    else
                        -- set the TDEmpty interrpt after the last data bit is sent
                        if coutbits = x"1" then
                            isr(5) <= '1';
                        end if;
                        -- shift the data shift register if not the start bit
                        -- shifting a 1 at the top end gives us the correct stop bit
                        if comms_mode = "10" and coutbits /= x"9" then
                            data_shift <= '1' & data_shift(7 downto 1);
                        end if;
                        -- move to the next state
                        coutbits <= std_logic_vector(unsigned(coutbits) - 1);
                    end if;
                end if;
                -- Generate the cassette out tone based on the current state
                if coutbits = x"9" or (unsigned(coutbits) > 0 and data_shift(0) = '0') then
                    -- start bit or data bit "0" = 1200Hz
                    casOut <= general_counter(13);
                else
                    -- stop bit or data bit "1" or any other time= 2400Hz
                    casOut <= general_counter(12);
                end if;

                -- ULA Writes
                if (cpu_clken = '1') then

                    ---- Detect control+caps
                    if (addr = x"9fff" and page_enable = '1' and page(2 downto 1) = "00") then
                        if (kbd(2 downto 1) = "00") then
                            ctrl_caps <= '1';
                        else
                            ctrl_caps <= '0';
                        end if;
                    end if;
                    -- Detect "2" being pressed: Turbo Speed
                    if (addr = x"b7ff" and page_enable = '1' and page(2 downto 1) = "00" and ctrl_caps = '1' and kbd(0) = '0') then
                        turbo <= '1';
                    end if;

                    if (addr(15 downto 8) = x"FE") then
                        if (R_W_n = '1') then
                            -- Clear the RDFull interrupts on reading the data_shift register
                            if (addr(3 downto 0) = x"4") then
                                isr(4) <= '0';
                            end if;
                        else
                            case addr(3 downto 0) is
                            when x"0" =>
                                ier(6 downto 2) <= data_in(6 downto 2);
                            when x"1" =>
                            when x"2" =>
                                screen_base(8 downto 6) <= data_in(7 downto 5);
                            when x"3" =>
                                screen_base(14 downto 9) <= data_in(5 downto 0);
                            when x"4" =>
                                data_shift <= data_in;
                                -- Clear the TDEmpty interrupt on writing the
                                -- data_shift register
                                isr(5) <= '0';
                            when x"5" =>
                                if (data_in(6) = '1') then
                                    -- Clear High Tone Detect IRQ
                                    isr(6) <= '0';
                                end if;
                                if (data_in(5) = '1') then
                                    -- Clear Real Time Clock IRQ
                                    isr(3) <= '0';
                                end if;
                                if (data_in(4) = '1') then
                                    -- Clear Display End IRQ
                                    isr(2) <= '0';
                                end if;
                                if (page_enable = '1' and page(2) = '0') then
                                    -- Roms 8-11 currently selected, so only selecting 8-15 will be honoured
                                    if (data_in(3) = '1') then
                                        page_enable <= data_in(3);
                                        page <= data_in(2 downto 0);
                                    end if;
                                else
                                    -- Roms 0-7 or 12-15 currently selected, so anything goes
                                    page_enable <= data_in(3);
                                    page <= data_in(2 downto 0);
                                end if;
                            when x"6" =>
                                counter <= data_in;
                            when x"7" =>
                                caps_int     <= data_in(7);
                                motor_int    <= data_in(6);
                                case (data_in(5 downto 3)) is
                                when "000" =>
                                    mode_base    <= "0110"; -- 0x3000
                                    mode_bpp     <= "00";
                                    mode_40      <= '0';
                                    mode_text    <= '0';
                                when "001" =>
                                    mode_base    <= "0110"; -- 0x3000
                                    mode_bpp     <= "01";
                                    mode_40      <= '0';
                                    mode_text    <= '0';
                                when "010" =>
                                    mode_base    <= "0110"; -- 0x3000
                                    mode_bpp     <= "10";
                                    mode_40      <= '0';
                                    mode_text    <= '0';
                                when "011" =>
                                    mode_base    <= "1000"; -- 0x4000
                                    mode_bpp     <= "00";
                                    mode_40      <= '0';
                                    mode_text    <= '1';
                                when "100" =>
                                    mode_base    <= "1011"; -- 0x5800
                                    mode_bpp     <= "00";
                                    mode_40      <= '1';
                                    mode_text    <= '0';
                                when "101" =>
                                    mode_base    <= "1011"; -- 0x5800
                                    mode_bpp     <= "01";
                                    mode_40      <= '1';
                                    mode_text    <= '0';
                                when "110" =>
                                    mode_base    <= "1100"; -- 0x6000
                                    mode_bpp     <= "00";
                                    mode_40      <= '1';
                                    mode_text    <= '1';
                                when "111" =>
                                    -- mode 7 seems to default to mode 4
                                    mode_base    <= "1011"; -- 0x5800
                                    mode_bpp     <= "00";
                                    mode_40      <= '1';
                                    mode_text    <= '0';
                                when others =>
                                end case;
                                comms_mode   <= data_in(2 downto 1);
                                -- A quirk of the Electron ULA is that RxFull
                                -- interrupt fires when tape output mode is
                                -- entered. Games like Southen Belle rely on
                                -- this quirk.
                                if data_in(2 downto 1) = "10" then
                                    isr(4) <= '1';
                                end if;
                            when others =>
                                -- A '1' in the palatte data means disable the colour
                                -- Invert the stored palette, to make the palette logic simpler
                                palette(slv2int(addr(2 downto 0))) <= data_in xor "11111111";
                            end case;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process; -- rtcint_cassette_regs

    caps  <= caps_int;
    motor <= motor_int;

    -- RGBs timing at 50Hz with a 16.000MHz Pixel Clock
    -- Horizontal 640 + (96 + 26) +  75 + (91 + 96) = total 1024
    -- Vertical   256 + (16 +  2) +   3 + (19 + 16) = total 312

    -- Note: The real ULA uses line 281->283/4 for VSYNC, but on both
    -- my TVs this loses part of the top line. So here we move the
    -- screen down by 7 rows. This should be transparent to software,
    -- as it doesn't affect the timing of the display or RTC
    -- interrupts. I'm happy to rever this is anyone complains!

    vsync_end    <= std_logic_vector(to_unsigned(276, 10)) when field = '0'                else
                    std_logic_vector(to_unsigned(277, 10));

    v_total      <= std_logic_vector(to_unsigned(311, 10)) when field = '0'                else
                    std_logic_vector(to_unsigned(312, 10));

    -- Indicate possible memory contention on active scan lines
    contention   <= '0' when  h_count >= h_active else
                    '0' when  (mode_text = '0' and v_count >= v_active_gph) else
                    '0' when  (mode_text = '1' and v_count >= v_active_txt) else
                    '0' when  (unsigned(char_row) >= 8) else
                    not mode_40;

    -- ToDo: Shouldn't this process be sensitive to RST_n/POR_n also?
    gen_video : process (clk_16M00,RST_IN_n)
        variable pixel : std_logic_vector(3 downto 0);
        -- start address of current row block (8-10 lines)
        variable row_addr  : std_logic_vector(14 downto 6);
        -- address within current line
        variable byte_addr : std_logic_vector(14 downto 3);
    begin
        if (RST_IN_n = '0') then
        -- H_COUNT controls the plotting of Pixels so really needs to be aligned to the DRAM VDU Cycles
        -- as soon as VDU Byte is aviailable it need to be plotted on the screen as the Pixels are
        -- immediately updated from that byte.
          resync_h_count <= '1';
          h_count <= (others => '0');
          v_count <= "0000000000";
          field <= '0';
          hsync_int <= '1';
          vsync_int <= '1';

        elsif rising_edge(clk_16M00) then

          if(clken_counter = x"7") then
            resync_h_count <= '0';
          end if;

          -- Horizontal counter, clocked at the pixel clock rate
          if resync_h_count = '1' then
              h_count <= (others => '0');
          elsif h_count = h_total then
              h_count <= (others => '0');
          else
              h_count <= std_logic_vector(unsigned(h_count) + 1);
          end if;

          -- Vertical counter, incremented at the end of each line
          if h_count = h_total then
              if v_count = v_total then
                  v_count <= (others => '0');
              else
                  v_count <= std_logic_vector(unsigned(v_count) + 1);
              end if;
          end if;

          if h_count = h_total and v_count = v_total then
            field <= not field;
          end if;

          -- Char_row counts 0..7 or 0..9 depending on the mode.
          -- It incremented on the trailing edge of hsync
          hsync_int_last <= hsync_int;
          if hsync_int = '1' and hsync_int_last = '0'  then
              if v_count = v_total then
                  char_row <= (others => '0');
              elsif v_count(0) = '1' or true then -- the 'true' here was: "mode(1) = '0'" I've stripped out mode, but don't really know how this works...
                  if last_line = '1' then
                      char_row <= (others => '0');
                  else
                      char_row <= std_logic_vector(unsigned(char_row) + 1);
                  end if;
              end if;
          elsif mode_text = '0' then
              -- From the ULA schematics sheet 7, VA3 is a T-type Latch
              -- with an additional reset input connected to GMODE, so it's
              -- immediately forced to zero in a graphics mode. This is
              -- needed for 0xC0DE's Vertical Rupture demo to work.
              char_row(3) <= '0';
          end if;

          -- Determine last line of a row
          -- char_row is (3 downto 0) so x"7" is ok as 1 nibble...
          if ((mode_text = '0' and char_row = x"7") or (mode_text = '1' and char_row = x"9")) and (v_count(0) = '1' or true) then -- as above true was "mode(1) = '0'"
              last_line <= '1';
          else
              last_line <= '0';
          end if;

          -- RAM Address, constructed from the local row_addr and byte_addr registers
          -- Some of this is taken from Hick's efforts to understand the schematics:
          -- https://www.mups.co.uk/project/hardware/acorn_electron/

          -- At start of the field, update row_addr and byte_addr from the ULA registers 2,3
          if h_count = h_reset_addr and v_count = v_total then
              row_addr  := screen_base;
              byte_addr := screen_base & "000";
          end if;

          -- At the start of hsync,  update the row_addr from byte_addr which
          -- gets to the start of the next block
          if hsync_int = '0' and last_line = '1' then
              row_addr := byte_addr(14 downto 6);
          end if;

          -- During hsync, reset byte reset back to start of line, unless
          -- it's the last line
          if hsync_int = '0' and last_line = '0' then
              byte_addr := row_addr & "000";
          end if;

          -- Every 8 or 16 pixels depending on mode/repeats
          if h_count < h_active then
              if (mode_40 = '0' and h_count(2 downto 0) = "000") or
                 (mode_40 = '1' and h_count(3 downto 0) = "1000") then
                  byte_addr := std_logic_vector(unsigned(byte_addr) + 1);
              end if;
          end if;

          -- Handle wrap-around back to mode_base
          if byte_addr(14 downto 11) = "0000" then
              byte_addr := mode_base & byte_addr(10 downto 3);
          end if;

          -- Screen_addr is the final 15-bit Video RAM address
          screen_addr <= byte_addr & char_row(2 downto 0);


          -- Pixels start being plotted on a row at h_count=0 so need to have the 
          -- Screen Data ready for then.
          -- RGB Data
          if (h_count >= h_active or 
            (mode_text = '0' and v_count >= v_active_gph) or 
            (mode_text = '1' and v_count >= v_active_txt) or 
            unsigned(char_row) >= 8) then
              -- blanking and border are always black
              red_int   <= '0';
              green_int <= '0';
              blue_int  <= '0';
          else
              -- rendering an actual pixel
              if (mode_bpp = "00") then
                  -- 1 bit per pixel, map to colours 0 and 8 for the palette lookup
                  if (mode_40 = '1') then
                      pixel := screen_data(7 - slv2int(h_count(3 downto 1))) & "000";
                  else
                      pixel := screen_data(7 - slv2int(h_count(2 downto 0))) & "000";
                  end if;
              elsif (mode_bpp = "01") then
                  -- 2 bits per pixel, map to colours 0, 2, 8, 10 for the palette lookup
                  if (mode_40 = '1') then
                      pixel := screen_data(7 - slv2int(h_count(3 downto 2))) & "0" &
                               screen_data(3 - slv2int(h_count(3 downto 2))) & "0";
                  else
                      pixel := screen_data(7 - slv2int(h_count(2 downto 1))) & "0" &
                               screen_data(3 - slv2int(h_count(2 downto 1))) & "0";
                  end if;
              else
                  -- 4 bits per pixel, map directly for the palette lookup
                  if (mode_40 = '1') then
                      pixel := screen_data(7 - sl2int(h_count(3))) &
                               screen_data(5 - sl2int(h_count(3))) &
                               screen_data(3 - sl2int(h_count(3))) &
                               screen_data(1 - sl2int(h_count(3)));
                  else
                      pixel := screen_data(7 - sl2int(h_count(2))) &
                               screen_data(5 - sl2int(h_count(2))) &
                               screen_data(3 - sl2int(h_count(2))) &
                               screen_data(1 - sl2int(h_count(2)));
                  end if;
              end if;
              -- Implement Color Palette
              case (pixel) is
              when "0000" =>
                  red_int   <= palette(1)(0);
                  green_int <= palette(1)(4);
                  blue_int  <= palette(0)(4);
              when "0001" =>
                  red_int   <= palette(7)(0);
                  green_int <= palette(7)(4);
                  blue_int  <= palette(6)(4);
              when "0010" =>
                  red_int   <= palette(1)(1);
                  green_int <= palette(1)(5);
                  blue_int  <= palette(0)(5);
              when "0011" =>
                  red_int   <= palette(7)(1);
                  green_int <= palette(7)(5);
                  blue_int  <= palette(6)(5);
              when "0100" =>
                  red_int   <= palette(3)(0);
                  green_int <= palette(3)(4);
                  blue_int  <= palette(2)(4);
              when "0101" =>
                  red_int   <= palette(5)(0);
                  green_int <= palette(5)(4);
                  blue_int  <= palette(4)(4);
              when "0110" =>
                  red_int   <= palette(3)(1);
                  green_int <= palette(3)(5);
                  blue_int  <= palette(2)(5);
              when "0111" =>
                  red_int   <= palette(5)(1);
                  green_int <= palette(5)(5);
                  blue_int  <= palette(4)(5);
              when "1000" =>
                  red_int   <= palette(1)(2);
                  green_int <= palette(0)(2);
                  blue_int  <= palette(0)(6);
              when "1001" =>
                  red_int   <= palette(7)(2);
                  green_int <= palette(6)(2);
                  blue_int  <= palette(6)(6);
              when "1010" =>
                  red_int   <= palette(1)(3);
                  green_int <= palette(0)(3);
                  blue_int  <= palette(0)(7);
              when "1011" =>
                  red_int   <= palette(7)(3);
                  green_int <= palette(6)(3);
                  blue_int  <= palette(6)(7);
              when "1100" =>
                  red_int   <= palette(3)(2);
                  green_int <= palette(2)(2);
                  blue_int  <= palette(2)(6);
              when "1101" =>
                  red_int   <= palette(5)(2);
                  green_int <= palette(4)(2);
                  blue_int  <= palette(4)(6);
              when "1110" =>
                  red_int   <= palette(3)(3);
                  green_int <= palette(2)(3);
                  blue_int  <= palette(2)(7);
              when "1111" =>
                  red_int   <= palette(5)(3);
                  green_int <= palette(4)(3);
                  blue_int  <= palette(4)(7);
              when others =>
              end case;
          end if;
          -- Vertical Sync, lasts 2.5 lines (160us)
          if (field = '0') then
              -- first field (odd) of interlaced scanning (or non interlaced)
              -- vsync starts at the beginning of the line
              -- h_count1 (10 downto 0)
              -- vsync_start = (274, 10) = 0100010010
              if (h_count = "00000000000" and v_count = "0100010010") then
                  vsync_int <= '0';
              elsif (h_count = ('0' & h_total(10 downto 1)) and v_count = vsync_end) then
                  vsync_int <= '1';
              end if;
          else
              -- second field (even) of intelaced scanning
              -- vsync starts half way through the line
              if (h_count = ('0' & h_total(10 downto 1)) and v_count = "0100010010") then
                  vsync_int <= '0';
              elsif (h_count = "00000000000" and v_count = vsync_end) then
                  vsync_int <= '1';
              end if;
          end if;
          -- Horizontal Sync
          if (h_count = hsync_start) then
              hsync_int <= '0';
          elsif (h_count = hsync_end) then
              hsync_int <= '1';
          end if;
          -- Display Interrupt, this is co-incident with the leading edge
          -- of hsync at the end the last active line of display
          -- (line 249 in text mode or line 255 in graphics mode)
          if (h_count = hsync_start) and ((v_count = v_disp_gph and mode_text = '0') or (v_count = v_disp_txt and mode_text = '1')) then
              display_intr <= '1';
          elsif (h_count = hsync_end) then
              display_intr <= '0';
          end if;
          -- RTC Interrupt, this occurs 8192us (200 lines) after the end of
          -- the vsync, and is not co-incident with hsync
          if (v_count = v_rtc) and ((field = '0' and h_count = "00000000000") or (field = '1' and h_count = ('0' & h_total(10 downto 1)))) then
              rtc_intr <= '1';
              -- v_count (9 downto 0)
          elsif (v_count = "0000000000") then
              rtc_intr <= '0';
          end if;
        end if;

      --DEBUG:
      -- pixel_debug <= pixel;
      -- start address of current row block (8-10 lines)
      -- row_addr_debug <= row_addr;
      -- address within current line
      -- byte_addr_debug <= byte_addr;

    end process;

    red   <= red_int;
    green <= green_int;
    blue  <= blue_int;
    csync <= hsync_int and vsync_int; -- HSync is CSync (Hsync AND VSync) 
    -- TODO: Should this be inverted?
    HS_n  <= not hsync_int;


--------------------------------------------------------
-- clock enable generator
--------------------------------------------------------

    -- Keyboard accesses always need to happen at 1MHz
    kbd_access <= '1' when addr(15 downto 14) = "10" and page_enable = '1' and page(2 downto 1) = "00" else '0';

    -- IO accesses always happen at 1MHz (no contention)
    -- This includes keyboard reads in paged ROM slots 8/9
    io_access <= '1' when addr(15 downto 8) = x"FC" or addr(15 downto 8) = x"FD" or addr(15 downto 8) = x"FE" or kbd_access = '1' else '0';

    -- RAM accesses always happen at 1MHz (with contention)
    ram_access <= '1' when addr(15) = '0' and turbo_ram_access = '0' else 
                  '0';

    -- Use Block RAM to serve CPU
    turbo_ram_access <= '1' when addr(15 downto 12) = x"0" and turbo = '1' else
                        '1' when addr(15 downto 12) = x"1" and turbo = '1' else 
                        '0';

    clk_gen1 : process(clk_16M00, POR_n)
    begin
      if (POR_n = '0') then
        -- This is an attempt to replace the Initial Signal Values

        clken_counter  <= (others => '0');
        cpu_clk <= '1';
        clk_counter <= (others => '0');

      elsif rising_edge(clk_16M00) then

        -- clken counter
        clken_counter <= std_logic_vector(unsigned(clken_counter) + 1);

        -- Logic to supress cpu cycles

        -- 2MHz/1MHz with Contention (match original Electron)
        --    RAM accesses 1MHz + contention
        --    ROM accesses 2MHz
        --     IO accesses 1MHz
        if clken_counter(2 downto 0) = "111" and clk_stopped = '0' then -- In GHDL this is also delayed 1 clock tick, again possible due to propgation
            cpu_clken <= '1';   -- Sim shows Clken =1 on clken_counter = "0000" clk_stopped = "00" (set to this one beat before)
        else
            cpu_clken <= '0';
        end if;

        -- Stop the clock on RAM or IO accesses, in the same way the ULA does
        if clk_stopped = '0' and clken_counter(2 downto 0) = "110" and (ram_access = '1' or io_access = '1') then
            clk_stopped <= '1'; -- STOP THE CLOCK!
        elsif clken_counter(3 downto 0) = "1110" and not (ram_access = '1' and contention = '1') then
            clk_stopped <= '0'; -- START THE CLOCK! 
        end if;

        -- Generate cpu_clk
        if cpu_clken = '1' then
            -- 1MHz or 2MHz clock; produce a 250 ns low pulse
            clk_counter <= "001";
            cpu_clk <= '0';
        elsif clk_counter(2) = '0' then -- clk_counter(2)
            clk_counter <= std_logic_vector(unsigned(clk_counter) + 1);
        else
            cpu_clk <= '1';
        end if;
      end if;
    end process;

    cpu_clk_out    <= cpu_clk;


    --------------------------------------------------------
    -- DRAM Bus Signals
    --------------------------------------------------------

    ram_addr <= addr(14 downto 0) when cpu_ram_slot = '1' else -- CPU
                screen_addr;  -- ULA


    -- Latching this to make sure it's only WRITING 
    dram_we_int_latch : process(clk_16M00, RST_IN_n)
    begin
      if(RST_IN_n = '0') then 
        dram_we_int <= '1';
      elsif(rising_edge(clk_16M00)) then
        if clken_counter (2 downto 0) = "000" then
          if cpu_ram_slot = '1' and ram_access = '1' and R_W_n = '0' then
            dram_we_int <= '0';
          else
            dram_we_int <= '1';
          end if;
        end if;
      end if;
    end process dram_we_int_latch;

    dram_clk_phase <= clken_counter(2 downto 0);

    -- Writing - Output Col1 data or Col2 Data on either CAS1 or CAS2
    dram_data_out(0)  <= data_in(0) when dram_cas1_int = '0' else
                         data_in(1) when dram_cas2_int = '0' else
                         'Z';
    dram_data_out(1)  <= data_in(2) when dram_cas1_int = '0' else
                         data_in(3) when dram_cas2_int = '0' else
                         'Z';
    dram_data_out(2)  <= data_in(4) when dram_cas1_int = '0' else
                         data_in(5) when dram_cas2_int = '0' else
                         'Z';
    dram_data_out(3)  <= data_in(6) when dram_cas1_int = '0' else
                         data_in(7) when dram_cas2_int = '0' else
                         'Z';

    -- DRAM Data Bus MUX
    dram_data <=  dram_data_out when dram_we_int = '0' else
                  (others => 'Z');

    dram_data_in <= dram_data;

    -- Reading DRAM Data into it's own Latch then data is ready
    dram_data_latching : process(clk_16M00, dram_ldcol1, RST_IN_n)
    begin
      if(RST_IN_n = '0') then
        dram_data_latch <= (others => 'Z');
      elsif(rising_edge(clk_16M00)) then
        if(dram_ldcol1 = '1') then
          dram_data_latch(0) <= dram_data_in(0);
          dram_data_latch(1) <= dram_data_in(1);
          dram_data_latch(2) <= dram_data_in(2);
          dram_data_latch(3) <= dram_data_in(3);
        end if;
      end if;
    end process dram_data_latching;

    -- Register CPU RAM Slot clocked at CLK_COUNTER[3] 
    cpu_ram_slot <= clken_counter(3) and (not contention);

    -- Load the DRAM Latched data to the ram_data register for outputting to the Data bus
    load_ram_data : process(clk_16M00, RST_IN_n)
    begin
      if(RST_IN_n = '0') then
         ram_data <= (others => '0');
      elsif(rising_edge(clk_16M00)) then  
        if dram_ldext = '1' and cpu_ram_slot = '1' and dram_we_int = '1' then -- RAM slot, LD Ext timing, READ cycle
          ram_data(0) <= dram_data_latch(0);
          ram_data(1) <= dram_data_in(0);
          ram_data(2) <= dram_data_latch(1);
          ram_data(3) <= dram_data_in(1);
          ram_data(4) <= dram_data_latch(2);
          ram_data(5) <= dram_data_in(2);
          ram_data(6) <= dram_data_latch(3);
          ram_data(7) <= dram_data_in(3);
        end if;
      end if;
    end process load_ram_data;

    -- Load data to the screen_data register for use in the VDU
    load_screen_data : process(clk_16M00, RST_IN_n)
    begin
      if(RST_IN_n = '0') then
         screen_data <= (others => '0');
      elsif(rising_edge(clk_16M00)) then
        if dram_ldext = '1' and cpu_ram_slot = '0' then
          screen_data(0) <= dram_data_latch(0);
          screen_data(1) <= dram_data_in(0);
          screen_data(2) <= dram_data_latch(1);
          screen_data(3) <= dram_data_in(1);
          screen_data(4) <= dram_data_latch(2);
          screen_data(5) <= dram_data_in(2);
          screen_data(6) <= dram_data_latch(3);
          screen_data(7) <= dram_data_in(3);
        end if;
      end if;
    end process load_screen_data;

    -- DRAM Address Mux
    with dram_addr_sel select
      dram_addr <=  ram_addr(7 downto 0)        when "00",
                    '0' & ram_addr(14 downto 8) when "01",
                    '1' & ram_addr(14 downto 8) when "10",
                    (others => '0')             when "11",
                    (others => '0')             when others;

    -- DRAM Controller FSM
    -- FSM Syncronous Process - state change & reset
    dramc_fsm_sync : process(clk_16M00, RST_IN_n, DRAMC_NS)
    begin
      if(RST_IN_n = '0') then
        DRAMC_PS <= RESET;
      elsif rising_edge(clk_16M00) then
        DRAMC_PS <= DRAMC_NS;
      end if;
    end process dramc_fsm_sync;

    -- FSM Combination Process - outputs based on current state
    dramc_fsm_conc : process(DRAMC_PS, dram_we_int, dram_clk_phase)
    begin
      -- Preassign the combinational outputs regardless of state - good practise and avoids creating latches
      dram_ras_int  <= '1';
      dram_cas1_int <= '1';
      dram_cas2_int <= '1';
      dram_ldcol1   <= '0';
      dram_ldcol2   <= '0';
      dram_ldext    <= '0';
      dram_addr_sel <= "11"; -- Zero

      case DRAMC_PS is

        when RESET => 
          dram_ras_int  <= '1';
          dram_cas1_int <= '1';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "00"; -- LSB
          if dram_clk_phase = "000" then
            DRAMC_NS <= ROW_LATCH;
          else
            DRAMC_NS <= RESET;
          end if;

        when ROW_LATCH => -- Phase 0
          dram_ras_int  <= '0';
          dram_cas1_int <= '1';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "00"; -- LSB
          if dram_clk_phase = "001" then 
            DRAMC_NS <= COL1_LATCH;
          else
            DRAMC_NS <= ROW_LATCH;
          end if;

        when COL1_LATCH => -- Phase 1
          dram_ras_int  <= '0';
          dram_cas1_int <= '0';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "01"; -- MSB-N1
          if dram_we_int = '1' and dram_clk_phase = "010" then -- Read Cycle 1 and clk phase 2 
            DRAMC_NS <= COL1_READ;
          elsif dram_we_int = '0' and dram_clk_phase = "011" then -- Write Cycle 1 and clk phase 3
            DRAMC_NS <= COL1_RESET;
          else
            DRAMC_NS <= COL1_LATCH;
          end if;

        when COL1_READ => -- Phase 2 (only on Read cycle)
          dram_ras_int  <= '0';
          dram_cas1_int <= '0';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0'; 
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "01"; -- MSB-N1
          if dram_clk_phase = "011" then
            DRAMC_NS <= COL1_RESET;
          else
            DRAMC_NS <= COL1_READ;
          end if;

        when COL1_RESET => -- Phase 3
          dram_ras_int  <= '0';
          dram_cas1_int <= '1';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '1';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "10"; -- MSB-N2
          if dram_clk_phase = "100" then
            DRAMC_NS <= COL2_LATCH;
          else
            DRAMC_NS <= COL1_RESET;
          end if;

        when COL2_LATCH => -- Phase 4
          dram_ras_int  <= '0';
          dram_cas1_int <= '1';
          dram_cas2_int <= '0';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "10"; -- MSB-N2
          if dram_we_int = '1' and dram_clk_phase = "101" then -- Read Cycle 2 and clk phase 5 
            DRAMC_NS <= COL2_READ;
          elsif dram_we_int = '0' and dram_clk_phase = "110" then -- Write Cycle 2 and clk phase 6
            DRAMC_NS <= ROWCOL2_RESET;
          else
            DRAMC_NS <= COL2_LATCH;
          end if;

        when COL2_READ => -- Phase 5 (only on read cycle)
          dram_ras_int  <= '0';
          dram_cas1_int <= '1';
          dram_cas2_int <= '0';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "10"; -- MSB-N2
          if dram_clk_phase = "110" then
            DRAMC_NS <= ROWCOL2_RESET;
          else
            DRAMC_NS <= COL2_READ;
          end if;

        when ROWCOL2_RESET => -- Phase 6
          dram_ras_int  <= '1';
          dram_cas1_int <= '1';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '1';
          dram_ldext    <= '1';
          dram_addr_sel <= "10"; -- MSB-N2 
          if dram_clk_phase = "111" then
            DRAMC_NS <= EXTLATCH_RESET;
          else
            DRAMC_NS <= ROWCOL2_RESET;
          end if;

        when EXTLATCH_RESET => -- Phase 7
          dram_ras_int  <= '1';
          dram_cas1_int <= '1';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0'; 
          dram_addr_sel <= "00"; -- LSB
          if dram_clk_phase = "000" then
            DRAMC_NS <= ROW_LATCH;
          else
            DRAMC_NS <= EXTLATCH_RESET;
          end if;

        when others =>
          dram_ras_int  <= '1';
          dram_cas1_int <= '1';
          dram_cas2_int <= '1';
          dram_ldcol1   <= '0';
          dram_ldcol2   <= '0';
          dram_ldext    <= '0';
          dram_addr_sel <= "11"; -- Zero
          DRAMC_NS <= RESET;
        end case;

    end process dramc_fsm_conc;

    cas1_delay : process(clk_16M00, dram_cas1_int)
    begin
        if(falling_edge(clk_16M00)) then
            dram_cas1_int_delay <= dram_cas1_int;
        end if;
    end process cas1_delay;

    cas_n   <=  dram_cas1_int_delay when DRAMC_PS = COL1_LATCH else
                dram_cas1_int and dram_cas2_int;
    ras_n   <= dram_ras_int;

    ram_we  <= dram_we_int;
    ram_nRW <= not dram_we_int;


    -- DEBUGGING FSM STATES
    -- RESET, ROW_LATCH, COL1_LATCH, COL1_READ, COL1_RESET, COL2_LATCH, COL2_READ, ROWCOL2_RESET, EXTLATCH_RESET
    --with DRAMC_PS select
    --    DRAMC_PS_DEBUG <=   "0000" when RESET,
    --                        "0001" when ROW_LATCH,
    --                        "0010" when COL1_LATCH,
    --                        "0011" when COL1_READ,
    --                        "0100" when COL1_RESET,
    --                        "0101" when COL2_LATCH,
    --                        "0110" when COL2_READ,
    --                        "0111" when ROWCOL2_RESET,
    --                        "1111" when EXTLATCH_RESET,
    --                        "1000" when others;

    --with DRAMC_NS select
    --    DRAMC_NS_DEBUG <=   "0000" when RESET,
    --                        "0001" when ROW_LATCH,
    --                        "0010" when COL1_LATCH,
    --                        "0011" when COL1_READ,
    --                        "0100" when COL1_RESET,
    --                        "0101" when COL2_LATCH,
    --                        "0110" when COL2_READ,
    --                        "0111" when ROWCOL2_RESET,
    --                        "1111" when EXTLATCH_RESET,
    --                        "1000" when others;
  

end behavioral;
