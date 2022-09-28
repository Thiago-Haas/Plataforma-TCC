library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.ceil;
use ieee.math_real.log2;

library work;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.all;
use work.bootloader_rom.all;

entity axi4l_rom_slave is
  generic (
    BASE_ADDR   : std_logic_vector(31 downto 0);
    HIGH_ADDR   : std_logic_vector(31 downto 0)
  );
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;
    -- AXI interface
    master_i : in  AXI4L_MASTER_TO_SLAVE;
    slave_o  : out AXI4L_SLAVE_TO_MASTER
  );
end entity;

architecture arch of axi4l_rom_slave is

  constant ADDR_WIDTH : integer := integer(ceil(log2(real(ROM_SIZE))));
  signal rom_w : rom_data_t := ROM_DATA;

  signal axislv_addr_w  : std_logic_vector(31 downto 0);
  signal axislv_rdata_w : std_logic_vector(31 downto 0);

begin
  axi4l_slave_u : axi4l_slave
  generic map (
    BASE_ADDR => BASE_ADDR,
    HIGH_ADDR => HIGH_ADDR
  )
  port map (
    clk_i      => clk_i,
    rstn_i     => rstn_i,
    master_i   => master_i,
    slave_o    => slave_o,
    wr_ready_i => '0',
    rd_ready_i => '1',
    done_i     => '1',
    error_i    => '0',
    rdata_i    => axislv_rdata_w,
    wr_en_o    => open,
    rd_en_o    => open,
    addr_o     => axislv_addr_w,
    prot_o     => open,
    wdata_o    => open,
    strb_o     => open
  );

  axislv_rdata_w <= rom_w(to_integer(unsigned(axislv_addr_w(ADDR_WIDTH+1 downto 2))));

end architecture;
