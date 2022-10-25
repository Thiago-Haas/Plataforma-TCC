library ieee;
use ieee.std_logic_1164.all;

library work;
use work.axi4l_pkg.all;

entity zed_top is
  port (
    btn_rst_i : in std_logic;
    clk_i     : in std_logic;

    -- UART
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic;

    -- GPIO
    user_btn_i : in    std_logic;
    leds_o     : out   std_logic_vector(7 downto 0);
    pmod_io    : inout std_logic_vector(3 downto 0)

  );
end zed_top;

architecture arch of zed_top is
  signal rstn_w        : std_logic;
  signal clk50_w       : std_logic;
  signal locked_w      : std_logic;
  signal periph_rstn_w : std_logic;

  signal gpio_tri_w : std_logic_vector(12 downto 0);
  signal gpio_rd_w  : std_logic_vector(12 downto 0);
  signal gpio_wr_w  : std_logic_vector(12 downto 0);
  
begin

  clk_wiz_0_u : entity work.clk_wiz_0
  port map (
    clk_in1  => clk_i,
    clk_out1 => clk50_w,
    locked   => locked_w
  );

  rstn_w <= locked_w and not btn_rst_i;

  -- fixed in or out pins
  gpio_rd_w(0) <= user_btn_i;
  leds_o <= gpio_wr_w(8 downto 1);
  gpio_rd_w(8 downto 1) <= gpio_wr_w(8 downto 1);
  -- configurable pins
  pmod_io(3) <= 'Z' when gpio_tri_w(12) = '1' else gpio_wr_w(12);
  pmod_io(2) <= 'Z' when gpio_tri_w(11) = '1' else gpio_wr_w(11);
  pmod_io(1) <= 'Z' when gpio_tri_w(10) = '1' else gpio_wr_w(10);
  pmod_io(0) <= 'Z' when gpio_tri_w( 9) = '1' else gpio_wr_w(9);
  gpio_rd_w(12) <= pmod_io(3);
  gpio_rd_w(11) <= pmod_io(2);
  gpio_rd_w(10) <= pmod_io(1);
  gpio_rd_w( 9) <= pmod_io(0);

