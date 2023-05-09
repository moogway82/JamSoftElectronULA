library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JamSoftElectronULA_vidtest_TB is
end;

architecture behavioral of JamSoftElectronULA_vidtest_TB is
  signal clk_16M00, R_W_n, data_en_n, POR_n, RST_IN_n, RST_OUT_n, IRQ_n, ROM_n, red, green, blue, csync, HS_n, sound, casIn, casOut, caps, motor, cpu_clk_out, testing_pin : std_logic;
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
    POR_n => POR_n,
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

  -- TODO: Change this to an Oper-Collector as I can't simulate keyboard RST (Break key)...
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
  
  begin



    -- wait until falling_edge(clk_16M00);
    POR_n <= '0';
    wait for  10 us;
    POR_n <= '1';

    wait until RST_OUT_n = '1';    

    -- simulate CPU Reset read from 0xFFFC & 0xFFFD
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFFC";
    data <= (others => 'Z');
    R_W_n <= '1';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FFFD";
    data <= (others => 'Z');
    R_W_n <= '1';

    -- 1) Set Mode 6
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE07";
    data <= "00110000"; 
    R_W_n <= '0';

    -- 2) Set Palette Reg
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE08";
    data <= "00010000"; 
    R_W_n <= '0';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE09";
    data <= "00010001"; 
    R_W_n <= '0';

    -- 3) Set the screen_start
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE02";
    data <= x"00"; 
    R_W_n <= '0';

    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"FE03";
    data <= x"30"; 
    R_W_n <= '0';

    -- 4) Write a 'A' and 'c' character bytes to &6140 and &6148
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6140"; 
    data <= x"3C";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6141"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6142"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6143"; 
    data <= x"7E";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6144"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6145"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6146"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6147"; 
    data <= x"00";
    R_W_n <= '0';
    -- 'c'
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6148"; 
    data <= x"00";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"6149"; 
    data <= x"00";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"614A"; 
    data <= x"3C";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"614B"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"614C"; 
    data <= x"60";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"614D"; 
    data <= x"66";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"614E"; 
    data <= x"3C";
    R_W_n <= '0';
    wait until falling_edge(cpu_clk_out);
    wait for cpu_addr_ready;
    addr <= x"614F"; 
    data <= x"00";
    R_W_n <= '0';

    wait for 22 ms;


    wait until falling_edge(cpu_clk_out);
    wait until falling_edge(cpu_clk_out);
    wait until falling_edge(cpu_clk_out);
    assert false report "** PASS ACTUALLY - End of testing **" severity failure;
    wait;
  end process;


end;