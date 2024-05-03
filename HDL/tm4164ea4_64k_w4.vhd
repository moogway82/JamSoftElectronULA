--
-- Copyright 2017 Gary Preston <gary@mups.co.uk>
-- All rights reserved
--
-- Redistribution and use in source and synthesized forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- License is granted for non-commercial use only.  A fee may not be charged
-- for redistributions as source code or in synthesized/hardware form without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--


-- Pseudo TM4164EA4 - 4 x 4164 64k 1bit RAM 
-- Original 4164 RAM was async however this module assumes all signals
-- are clock synchronised and implements the read/write protocol that the
-- temporary ULA is using. This will be revisited once more is understood about
-- the real workings of the ULA.
--
-- Read
--  1 - we, /ras = addr latched for row
--  2 - /cas = addr used for col and read occurs
--  3 - data out valid, /ras & /cas may return high
--  4 - data out goes Z
--
-- Write
--  1 - ras low = addr latched for row
--  2 - data in, cas low, we low = addr used for col, data written to row/col
--  3 - we high, cas & ras high
--
-- Not implemented: any of the other cycles including paged reads.
-- This implementation is a little more convoluted than it perhaps needed to be
-- due to sticking with a pin accurate ULA mapping.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity TM4164EA3_64k_W4 is 
  -- 64k 0x000 - 0x3FFFF
  port (
    -- clock for sync bram 
    i_clk                       : in std_logic;

    i_addr                      : in std_logic_vector(7 downto 0);

    --i_data                      : in std_logic_vector(3 downto 0);
    --o_data                      : out std_logic_vector(3 downto 0);
    data                        : inout std_logic_vector(3 downto 0);
  
    i_n_we                      : in std_logic;
    i_n_ras                     : in std_logic;
    i_n_cas                     : in std_logic
    );
end;

architecture RTL of TM4164EA3_64k_W4 is
  -- multiplexed addressing
  signal row_addr               : std_logic_vector(7 downto 0) := (others => '0');

  -- edge detection
  signal n_cas_edge, n_cas_l    : std_logic := '0';
  signal n_ras_edge, n_ras_l    : std_logic := '0';

  signal read_data              : std_logic_vector(3 downto 0) := (others => '0');

  type ram_type is array (65535 downto 0) of std_logic_vector(3 downto 0);
  shared variable RAM : ram_type;

begin 

  --  Unsyntesisable process to just populate the RAM
  fill_ram : process 
    variable test_data : unsigned(3 downto 0) := "0000";
  begin
    for i in 0 to 65535 loop
      RAM(i) := std_logic_vector(test_data);
      test_data := test_data + 1;
    end loop;
    wait;
  end process fill_ram;

  -- data <= read_data when (i_n_ras = '0' and i_n_cas = '0' and i_n_we = '1') else (others => 'Z');
  data <= read_data when (i_n_we = '1') else (others => 'Z');

  -- edge detection of ras and cas signals
  p_edge_detect : process (i_clk)
  begin
    if rising_edge(i_clk) then
      n_cas_l <= i_n_cas;
      n_ras_l <= i_n_ras;
    end if;
  end process;
  -- rising edge detect
  -- n_cas <= not n_cas_l and i_n_cas;
  -- n_ras <= not n_ras_l and i_n_ras;

  -- falling edge detect
  n_cas_edge <= (not i_n_cas) and n_cas_l;
  n_ras_edge <= (not i_n_ras) and n_ras_l;

  p_ras_cas : process(i_clk)
    -- active read/write address
    variable addr : std_logic_vector(15 downto 0) := (others => '0');
  begin
    if rising_edge(i_clk) then
      -- multiplexed address decoding
      if (n_ras_edge = '1') then
        row_addr <= i_addr;
      end if;

      if (n_cas_edge = '1') then
        -- Full nibble address
        addr := row_addr & i_addr;

        if (i_n_we = '0') then
          RAM(to_integer(unsigned(addr))) := data;
        end if;
        read_data <= RAM(to_integer(unsigned(addr)));
      end if;
      
    end if;

    -- Other modes that may be needed if used by ULA
    --   * read-write/read-modify-write cycles
    --   * page mode read cycle
    --   * page mode write cycle

    -- Implementation not needed just ensure it doesn't break anything if used:
    --   * ras only refresh cycle 
    --   * hidden refresh cycle

  end process;


end;
