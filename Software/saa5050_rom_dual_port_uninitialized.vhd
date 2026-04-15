library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity saa5050_rom_dual_port_uninitialized is
    generic (
        ADDR_WIDTH       : integer := 12;
        DATA_WIDTH       : integer := 8
    );
    port(
        clock    : in  std_logic;
        wea      : in  std_logic;
        addressA : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        dina     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        QA       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        addressB : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        QB       : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end saa5050_rom_dual_port_uninitialized;

architecture RTL of saa5050_rom_dual_port_uninitialized is

    constant MEM_DEPTH : integer := 2**ADDR_WIDTH;
    type mem_type is array (0 to MEM_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    shared variable mem : mem_type;

 begin

    process(clock)
    begin
        if (rising_edge(clock)) then
            if wea = '1' then
                mem(to_integer(unsigned(addressA))) := dina;
            end if;
            QA <= mem(to_integer(unsigned(addressA)));
            --QA <= addressA(7 downto 0);  --DEBUG generate something until memory init works
        end if;
    end process;

    process(clock)
    begin
        if (rising_edge(clock)) then
            QB <= mem(to_integer(unsigned(addressB)));
            --QB <= addressB(7 downto 0);  --DEBUG generate something until memory init works
        end if;
    end process;

end RTL;
