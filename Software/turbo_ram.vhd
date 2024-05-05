library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity turbo_ram is
  generic (
    addr_width : natural := 13;--8192x8
    data_width : natural := 8
  );
  port (
    addr : in std_logic_vector (addr_width - 1 downto 0);
    write_en : in std_logic;
    rclk : in std_logic;
    wclk : in std_logic;
    din : in std_logic_vector (data_width - 1 downto 0);
    dout : out std_logic_vector (data_width - 1 downto 0)
  );
  end turbo_ram;

  architecture rtl of turbo_ram is
    type mem_type is array ((2** addr_width) - 1 downto 0) of
      std_logic_vector(data_width - 1 downto 0);
    signal mem : mem_type;

  begin
    
    ram_write: process (wclk)
    begin
      if rising_edge(wclk) then
        if (write_en = '1') then
          mem(to_integer(unsigned(addr))) <= din;
        end if;
      end if;
    end process ram_write;
    
    ram_read: process (rclk)
    begin
      if(rising_edge(rclk)) then
        dout <= mem(to_integer(unsigned(addr)));
      end if;
    end process ram_read;

end rtl;