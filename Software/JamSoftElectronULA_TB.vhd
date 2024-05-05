library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity JamSoftElectronULA_TB is
end;

architecture behavioral of JamSoftElectronULA_TB is
  signal clk_16M00, data_en, R_W_n, RST_n, IRQ_n, NMI_n, ROM_n, red, green, blue, vsync, csync, HS_n, sound, casIn, casOut, caps, motor, cpu_clken_out, cpu_clk_out : std_logic;
  signal addr : std_logic_vector(15 downto 0);
  signal data_in, data_out, cpu_data_in : std_logic_vector(7 downto 0);
  signal rom_latch, kbd : std_logic_vector(3 downto 0);
  -- New RAM Signals:
  signal dram_data : std_logic_vector(3 downto 0);
  signal dram_addr : std_logic_vector(7 downto 0);
  signal ras_n     : std_logic;
  signal cas_n     : std_logic;
  signal ram_we    : std_logic;

  signal cpu_addr          : std_logic_vector(23 downto 0);
  signal phi1_out  : std_logic;


  constant c_clk_period : time := 1 us / 16.0; -- MHz
begin

  ula : entity work.JamSoftElectronULA 
  port map(
    clk_16M00 => clk_16M00,
    addr => addr,
    data_in => data_in,
    data_out => data_out,
    data_en => data_en,
    R_W_n => R_W_n,
    RST_n => RST_n,
    IRQ_n => IRQ_n,
    NMI_n => NMI_n,
    -- New RAM signals
    dram_data => dram_data,
    dram_addr => dram_addr,
    ras_n => ras_n,
    cas_n => cas_n,
    ram_we => ram_we,

    ROM_n => ROM_n,
    red => red,
    green => green,
    blue => blue,
    csync => csync,
    HS_n  => open,  -- TODO is this unused?
    sound => sound,
    kbd => kbd,
    casIn => casIn,
    casOut => casOut,
    caps => caps,
    motor => motor,
    rom_latch => rom_latch,
    cpu_clken_out => cpu_clken_out,
    cpu_clk_out => cpu_clk_out
  );

  ram1 : entity work.dram_64k_w4 
  port map(
    address => dram_addr,                     --: in std_logic_vector(7 downto 0);
    data => dram_data,                     --: out std_logic_vector(3 downto 0);
    WE => ram_we,                     --: in std_logic;
    RAS => ras_n,                    --: in std_logic;
    CAS => cas_n                    --: in std_logic
  );

  -- Test CPU Cre
  T65core : entity work.T65
    port map (
      Mode            => "00",
      Abort_n         => '1',
      SO_n            => '1',  -- Signal not routed to the ULA
      Res_n           => RST_n,
      Enable          => '1',
      Clk             => cpu_clk_out,
      Rdy             => '1',  -- Signal not routed to the ULA
      IRQ_n           => IRQ_n,
      NMI_n           => '1',
      R_W_n           => R_W_n,
      Sync            => open,  -- Signal not routed to the ULA
      A               => cpu_addr,
      DI              => cpu_data_in,
      DO              => data_in
    );
  addr <= cpu_addr(15 downto 0);

  -- OS ROM
  OSROM1 : entity work.RomOS100
    port map (
      addr => addr(13 downto 0),
      data => cpu_data_in,
      oe_n => ROM_n,
      cs_n => phi1_out
    );

  phi1_out <= not cpu_clk_out;

  data_out <= (others => 'Z') when ROM_n = '0' else 
              cpu_data_in;

  p_clk_gen : process begin
    clk_16M00 <= '1';
    wait for c_clk_period / 2;
    clk_16M00 <= '0';
    wait for c_clk_period / 2;
    
  end process;

  tb : process begin
    -- wait until falling_edge(clk_16M00);
    RST_n <= '0';
    wait for  c_clk_period * 4;
    RST_n <= '1';
    
    wait for 100 us;

    assert false report "End of testing, phew!" severity failure;
    wait;
  end process;

end;