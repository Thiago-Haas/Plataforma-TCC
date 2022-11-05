library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi4l_pkg.AXI4L_S2M_DECERR;

entity top_tb is
end entity;

architecture arch of top_tb is
  constant period : time := 20 ns;
  signal rstn : std_logic := '0';
  signal clk  : std_logic := '0';

  signal top_uart_tx : std_logic;

  signal rec_done : std_logic;
  signal rec_data : std_logic_vector(7 downto 0);

  constant GPIO_SIZE : integer := 13;
  signal gpio_tri_o : std_logic_vector(GPIO_SIZE-1 downto 0);
  signal gpio_rd_i  : std_logic_vector(GPIO_SIZE-1 downto 0);
  signal gpio_wr_o  : std_logic_vector(GPIO_SIZE-1 downto 0);

  signal user_btn_i : std_logic;
  signal leds_o     : std_logic_vector(7 downto 0);
  signal pmod_io    : std_logic_vector(3 downto 0);

begin
  rstn <= '1' after period;
  clk  <= not clk after period/2;

  top_u : entity work.top
  generic map (
    PROGRAM_START_ADDR => x"{{ PROGRAM_START_ADDR }}",
    IS_SIMULATION      => TRUE,
    AHX_FILEPATH       => "{{ AHX_FILEPATH }}"
  )
  port map (
    poweron_rstn_i => rstn,
    clk_i          => clk,
    btn_rstn_i     => '1',
    start_i        => '1',
    periph_rstn_o  => open,
    -- uart
    uart_rx_i      => '1',
    uart_tx_o      => top_uart_tx,
    uart_cts_i     => '0',
    uart_rts_o     => open,
    -- gpio
    gpio_tri_o     => gpio_tri_o,
    gpio_rd_i      => gpio_rd_i,
    gpio_wr_o      => gpio_wr_o,
    -- AXI
    axi4l_master_o => open,
    axi4l_slave_i  => AXI4L_S2M_DECERR,
    ext_event_i    => '0'
  );
  -- fixed in or out pins
  gpio_rd_i(0) <= '0';
  leds_o <= gpio_wr_o(8 downto 1);
  gpio_rd_i(8 downto 1) <= gpio_wr_o(8 downto 1);
  -- configurable pins
  pmod_io(3) <= 'Z' when gpio_tri_o(12) = '1' else gpio_wr_o(12);
  pmod_io(2) <= 'Z' when gpio_tri_o(11) = '1' else gpio_wr_o(11);
  pmod_io(1) <= 'Z' when gpio_tri_o(10) = '1' else gpio_wr_o(10);
  pmod_io(0) <= 'Z' when gpio_tri_o( 9) = '1' else gpio_wr_o(9);
  gpio_rd_i(12) <= pmod_io(3);
  gpio_rd_i(11) <= pmod_io(2);
  gpio_rd_i(10) <= pmod_io(1);
  gpio_rd_i( 9) <= pmod_io(0);


  uart_u : entity work.uart
  port map (
    baud_div_i => x"01B2", -- 115200 @ 50 MHz
    parity_i   => '0',
    rtscts_i   => '1',
    tstart_i   => '0',
    tdata_i    => x"00",
    tdone_o    => open,
    rready_i   => '1',
    rdone_o    => rec_done,
    rdata_o    => rec_data,
    rerr_o     => open,
    rstn_i     => rstn,
    clk_i      => clk,
    uart_rx_i  => top_uart_tx,
    uart_tx_o  => open,
    uart_cts_i => '0',
    uart_rts_o => open
 );

  -- print UART output to console
  process
    variable rchar : character;
    variable rdata : string(1 to 128);
    variable size  : integer range 0 to 128;
  begin
    size := 0;
    wait until rstn = '1';
    loop
      wait until rising_edge(clk) and rec_done = '1';
      rchar := character'val(to_integer(unsigned(rec_data)));
      size := size + 1;
      rdata(size) := rchar;
      -- check if it is line break
      if rchar = lf then
        -- print line
        report lf & "[HARV] " & rdata(1 to size-1);
        -- reset string size
        size := 0;
        -- check simulation stop commands
        if rdata(1 to 6) = "Exited" then -- stop simulation on exit
          std.env.finish;
        elsif rdata(1 to 8) = "halt-sim" then -- stop simulation on stop-sim print
          std.env.finish;
        end if;
      end if;
    end loop;
  end process;

  -- print leds modifications to console
  process
    variable last_leds_v : std_logic_vector(7 downto 0);
  begin
    last_leds_v := leds_o;
    -- wait modification
    wait until rising_edge(clk) and leds_o /= last_leds_v;
    -- report new value
    report lf & "[LEDS] " & std_logic'image(leds_o(7))
                          & std_logic'image(leds_o(6))
                          & std_logic'image(leds_o(5))
                          & std_logic'image(leds_o(4))
                          & std_logic'image(leds_o(3))
                          & std_logic'image(leds_o(2))
                          & std_logic'image(leds_o(1))
                          & std_logic'image(leds_o(0));
  end process;

end architecture;
