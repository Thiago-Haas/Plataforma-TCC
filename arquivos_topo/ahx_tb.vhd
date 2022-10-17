library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

use std.textio.all;

library work;
use work.axi4l_pkg.all;

entity ahx_tb is
  generic (
    MEM_SIZE_MB  : integer := 8;
    AHX_FILEPATH : string  := "../../../../../src/helloworld/out/app-sim.ahx";
    OUT_FILE     : string := ""
  );
end entity;

architecture arch of ahx_tb is
  signal period : time := 20 ns; -- 50 MHz
  signal clk    : std_logic := '1';
  signal rstn   : std_logic := '0';
  signal start  : std_logic := '0';
  
  signal periph_rstn_o : std_logic;

  -- UART receiver
  signal top_uart_tx : std_logic;
  signal rec_data : std_logic_vector(7 downto 0);
  signal rec_done : std_logic;
  -- UART sender to test scanf
  signal top_uart_rx : std_logic;
  signal send_data : std_logic_vector(7 downto 0);
  signal send_start : std_logic;
  signal sender_done : std_logic;

  -- GPIO
  signal gpio_tri_o : std_logic_vector(12 downto 0);
  signal gpio_rd_i  : std_logic_vector(12 downto 0);
  signal gpio_wr_o  : std_logic_vector(12 downto 0);

begin

  -- BASIC SIGNALS
  rstn <= '1' after period*2;
  clk  <= not clk after period/2;
  start <= '1' after period*2;

  top_b : block
    -- AXI4lite interface
    signal axi4l_master  : AXI4L_MASTER_TO_SLAVE;
    signal axi4l_slave   : AXI4L_SLAVE_TO_MASTER;

    constant DMEM_BASE_ADDR : std_logic_vector(31 downto 0) := x"08000000";
    constant DMEM_HIGH_ADDR : std_logic_vector(31 downto 0) := x"08000FFF";
    constant BRAM_BASE_ADDR : std_logic_vector(31 downto 0) := x"70000000";
    constant BRAM_HIGH_ADDR : std_logic_vector(31 downto 0) :=
      std_logic_vector(unsigned(BRAM_BASE_ADDR) + to_unsigned(MEM_SIZE_MB * 1024 * 1024, 32) - 1);
    constant MEH_BASE_ADDR  : std_logic_vector(31 downto 0) := x"70800000";
    constant MEH_HIGH_ADDR  : std_logic_vector(31 downto 0) := x"7080001F";

    constant PROGRAM_START_ADDR : std_logic_vector(31 downto 0) := x"70000000";

  begin

    harv_soc_u : entity work.harv_soc_bram
    generic map (
      PROGRAM_START_ADDR => PROGRAM_START_ADDR,
      HARV_TMR           => TRUE,
      HARV_ECC           => TRUE,
      ENABLE_ROM         => FALSE,
      ENABLE_DMEM        => FALSE,
      ENABLE_DMEM_ECC    => FALSE,
      DMEM_BASE_ADDR     => DMEM_BASE_ADDR,
      DMEM_HIGH_ADDR     => DMEM_HIGH_ADDR,
      BRAM_BASE_ADDR     => BRAM_BASE_ADDR,
      BRAM_HIGH_ADDR     => BRAM_HIGH_ADDR,
      ENABLE_BRAM_ECC    => TRUE,
      MEH_BASE_ADDR      => MEH_BASE_ADDR,
      MEH_HIGH_ADDR      => MEH_HIGH_ADDR,
      GPIO_SIZE          => 13,
      IS_SIMULATION      => TRUE,
      AHX_FILEPATH       => AHX_FILEPATH
    )
    port map (
      poweron_rstn_i => rstn,
      btn_rstn_i     => '1',
      clk_i          => clk,
      start_i        => start,
      periph_rstn_o  => periph_rstn_o,
      -- UART interface
      uart_rx_i  => top_uart_rx,
      uart_tx_o  => top_uart_tx,
      uart_cts_i => '0',
      uart_rts_o => open,
      -- GPIO
      gpio_tri_o => gpio_tri_o,
      gpio_rd_i  => gpio_rd_i,
      gpio_wr_o  => gpio_wr_o,
      -- AXI4-lite FLASH interface
      axi4l_master_o => axi4l_master,
      axi4l_slave_i  => axi4l_slave,
      -- external event
      ext_event_i => '0'
    );
  end block;

  uart_u : entity work.uart
  port map (
    baud_div_i => x"01B2", -- 115200
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
    uart_rts_o => open,
    uart_cts_i => '0'
 );

  -- print UART output to console
  process
    variable rchar : character;
    variable rdata : string(1 to 128);
    variable size  : integer range 0 to 128;
    -- output file variables
    file     file_ptr  : text;
    variable file_line : line;
    variable fstatus   : file_open_status;
  begin
    -- open file to write output
    if OUT_FILE /= "" then
      file_open(fstatus, file_ptr, OUT_FILE, write_mode);
    end if;

    size := 0;
    wait until start = '1';
    loop
      wait until rising_edge(clk) and rec_done = '1';
      rchar := character'val(to_integer(unsigned(rec_data)));
      size := size + 1;
      rdata(size) := rchar;
      -- check if it is line break
      if rchar = lf then
        -- print line
        report lf & "[HARV] " & rdata(1 to size-1);
        -- if there is an output file
        if OUT_FILE /= "" then
          -- write execution timestamp
          write(file_line, time'image(now));
          -- write HARV prefix
          write(file_line, string'(" [HARV] "));
          -- write print
          write(file_line, rdata(1 to size-1));
          -- save line to file
          writeline(file_ptr, file_line);
        end if;
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

  process
    variable last_leds_v : std_logic_vector(7 downto 0);
  begin
    last_leds_v := gpio_wr_o(8 downto 1);
    wait until rising_edge(clk) and gpio_wr_o(8 downto 1) /= last_leds_v;
    report lf & "[LEDS] " & std_logic'image(gpio_wr_o(8))
                          & std_logic'image(gpio_wr_o(7))
                          & std_logic'image(gpio_wr_o(6))
                          & std_logic'image(gpio_wr_o(5))
                          & std_logic'image(gpio_wr_o(4))
                          & std_logic'image(gpio_wr_o(3))
                          & std_logic'image(gpio_wr_o(2))
                          & std_logic'image(gpio_wr_o(1));
  end process;

end architecture;
