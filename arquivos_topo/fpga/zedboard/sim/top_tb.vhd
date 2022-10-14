library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_tb is
end entity;

architecture arch of top_tb is
  constant period : time := 10 ns;
  signal rstn : std_logic := '0';
  signal clk  : std_logic := '0';

  signal top_uart_rx : std_logic;
  signal top_uart_tx : std_logic;

  signal send_data   : std_logic_vector(7 downto 0);
  signal send_start  : std_logic;
  signal sender_done : std_logic;

  signal rec_done : std_logic;
  signal rec_data : std_logic_vector(7 downto 0);

begin
  rstn <= '1' after period;
  clk  <= not clk after period/2;

  process
    variable tdata : string(1 to 28) := "170000000CAFECAFE" & lf & "270000000" & lf;
    variable size  : integer := 28;
  begin
    send_start <= '0';
    wait for 1 ms;

    for i in 1 to size loop
      send_data <= std_logic_vector(to_unsigned(character'pos(tdata(i)), 8));
      send_start <= '1';
      wait for period;
      send_start <= '0';
      while sender_done = '0' loop
        wait until rising_edge(clk);
      end loop;
      wait for period;
      -- wait for 9 us;
      -- wait for 1 ms;

    end loop;

  end process;

  top_u : entity work.top
  port map (
    btn_rst_i  => '0',
    clk_i      => clk,
    uart_rx_i  => top_uart_rx,
    uart_tx_o  => top_uart_tx,
    uart_cts_i => '0',
    uart_rts_o => open,
    user_btn_i => '0',
    leds_o     => open,
    pmod_io    => open
  );

  uart_u : entity work.uart
  port map (
    baud_div_i => x"0364", -- 115200
    parity_i   => '0',
    rtscts_i   => '1',
    tstart_i   => send_start,
    tdata_i    => send_data,
    tdone_o    => sender_done,
    rready_i   => '1',
    rdone_o    => rec_done,
    rdata_o    => rec_data,
    rerr_o     => open,
    rstn_i     => rstn,
    clk_i      => clk,
    uart_rx_i  => top_uart_tx,
    uart_tx_o  => top_uart_rx,
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
