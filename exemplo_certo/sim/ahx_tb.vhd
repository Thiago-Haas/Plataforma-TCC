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
    AHX_FILEPATH : string;
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

    constant DMEM_BASE_ADDR    : std_logic_vector(31 downto 0) := x"08000000"; -- definidas pelo programa
    constant DMEM_HIGH_ADDR    : std_logic_vector(31 downto 0) := x"08000FFF"; -- definidas pelo programa
    constant EXT_RAM_BASE_ADDR : unsigned(31 downto 0)         := x"70000000";
    constant EXT_RAM_HIGH_ADDR : unsigned(31 downto 0)         := unsigned(EXT_RAM_BASE_ADDR) + to_unsigned(MEM_SIZE_MB * 1024 * 1024, 32) - 1;

    constant PROGRAM_START_ADDR : std_logic_vector(31 downto 0) := x"70000000";

    type mem_t is array(natural range <>) of std_logic_vector(7 downto 0);
    signal ext_ram : mem_t(to_integer(EXT_RAM_HIGH_ADDR) downto to_integer(EXT_RAM_BASE_ADDR));

    procedure load_memory (
        constant FILE_PATH : in string;
        constant BASE_ADDR : in integer;
        signal mem : out mem_t
      ) is
        file     file_v  : text;
        variable line_v  : line;
        variable addr_v  : std_logic_vector(31 downto 0);
        variable sep_v   : character;
        variable byte_v  : std_logic_vector(7 downto 0);
        variable error_v : boolean;
    begin
      -- read ahx file
      file_open(file_v, FILE_PATH, READ_MODE);
      -- iterate through all lines in the file
      while not endfile(file_v) loop
        -- read line from file_v
        readline(file_v, line_v);
        -- ensure that the line is not empty
        if line_v'length > 0 then
          -- read hex address
          hread(line_v, addr_v, error_v);
          -- assert if the hread had an error
          assert (error_v) report "Text I/O read error" severity FAILURE;
          -- read separator
          read(line_v, sep_v);
          -- read hex byte
          hread(line_v, byte_v, error_v);
          -- assert if the hread had an error
          assert (error_v) report "Text I/O read error" severity FAILURE;
          -- write byte to memory
          mem(to_integer(unsigned(addr_v)) + BASE_ADDR) <= byte_v;
        end if;
      end loop;
      file_close(file_v);
    end procedure;
  begin

    top_u : entity work.top
    generic map (
      GPIO_SIZE     => 13
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

    -- External memory
    process
      variable addr_v  : unsigned(31 downto 0);
      variable wdata_v : std_logic_vector(31 downto 0);
    begin
      report lf & "Initializing external memory from " & AHX_FILEPATH;
      -- load memory from path
      load_memory(AHX_FILEPATH, to_integer(EXT_RAM_BASE_ADDR), ext_ram);
      report lf & "Memory loaded";

      -- initialize signals
      -- write op
      axi4l_slave.awready <= '0';
      axi4l_slave.wready  <= '0';
      axi4l_slave.bresp   <= RESPONSE_DECERR;
      axi4l_slave.bvalid  <= '0';
      -- read op
      axi4l_slave.arready <= '0';
      axi4l_slave.rresp   <= RESPONSE_DECERR;
      axi4l_slave.rvalid  <= '0';

      -- wait reset
      wait until rstn = '1';
      -- infinite loop to listen to APB3 requests
      loop
        -- wait request
        wait until rising_edge(clk) and (axi4l_master.awvalid or axi4l_master.arvalid) = '1';

        -- verify if it's write operation
        if axi4l_master.awvalid = '1' then
          -- saves address
          addr_v := unsigned(axi4l_master.awaddr);

          -- gives ready signal
          axi4l_slave.awready <= '1';
          wait for period;
          axi4l_slave.awready <= '0';
          
          -- waits data
          wait until rising_edge(clk) and axi4l_master.wvalid = '1';
          wdata_v := axi4l_master.wdata;
          -- gives ready signal
          axi4l_slave.wready <= '1';
          wait for period;
          axi4l_slave.wready <= '0';

          -- if address is in range
          if EXT_RAM_BASE_ADDR <= addr_v and addr_v <= EXT_RAM_HIGH_ADDR - 3 then
            -- writes data to memory (respecting strobe)
            for i in 0 to 3 loop
              if axi4l_master.wstrb(i) = '1' then
                ext_ram(to_integer(addr_v)+i) <= wdata_v((i+1)*8-1 downto i*8);
              end if;
            end loop;
  
            -- gives valid response signal
            axi4l_slave.bvalid <= '1';
            axi4l_slave.bresp  <= RESPONSE_OKAY;

          else -- _else: address not in range
            report "Invalid AMBA write access " & to_hstring(axi4l_master.awaddr) severity WARNING;
            -- gives ERROR response signal
            axi4l_slave.bvalid <= '1';
            axi4l_slave.bresp  <= RESPONSE_DECERR;
          end if;

          -- wait until ready
          wait until rising_edge(clk) and axi4l_master.bready = '1';
          wait for period;
          -- stops valid signal
          axi4l_slave.bvalid <= '0';
          axi4l_slave.bresp  <= RESPONSE_DECERR;

        -- verify if it's read operation
        elsif axi4l_master.arvalid = '1' then
          -- saves address
          addr_v := unsigned(axi4l_master.araddr);

          -- gives ready signal
          axi4l_slave.arready <= '1';
          wait for period;
          axi4l_slave.arready <= '0';
          
          -- if address is in range
          if EXT_RAM_BASE_ADDR <= addr_v and addr_v <= EXT_RAM_HIGH_ADDR - 3 then
            -- gives data response signal
            axi4l_slave.rvalid <= '1';
            axi4l_slave.rresp  <= RESPONSE_OKAY;
            -- reads data from memory
            for i in 0 to 3 loop
              axi4l_slave.rdata((i+1)*8-1 downto i*8) <= ext_ram(to_integer(addr_v)+i);
            end loop;

          else -- _else: address not in range

            report "Invalid AMBA read access " & to_hstring(axi4l_master.araddr) severity WARNING;
            -- gives data ERROR response signal
            axi4l_slave.rvalid <= '1';
            axi4l_slave.rresp  <= RESPONSE_DECERR;
            axi4l_slave.rdata  <= x"deadbeef";
          end if;

          -- wait until ready
          wait until rising_edge(clk) and axi4l_master.rready = '1';
          wait for period;
          -- stops valid signal
          axi4l_slave.rvalid <= '0';
          axi4l_slave.rresp  <= RESPONSE_DECERR;
          axi4l_slave.rdata  <= x"deadbeef";

        end if;

      end loop;
    end process;
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
