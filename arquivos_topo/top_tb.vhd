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
    gpio_tri_o     => open,
    gpio_rd_i      => (others => '0'),
    gpio_wr_o      => open,
    -- AXI
    axi4l_master_o => open,
    axi4l_slave_i  => AXI4L_S2M_DECERR
  );

  uart_u : entity work.uart
  port map (
    baud_div_i => x"0364", -- 115200
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
      if rchar = lf then
        report "Processor wrote: " & rdata(1 to size);
        size := 0;
      end if;
    end loop;
  end process;

end architecture;
