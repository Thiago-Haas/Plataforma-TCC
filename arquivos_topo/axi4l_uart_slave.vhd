library ieee;
use ieee.std_logic_1164.all;

library work;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.axi4l_slave;

entity axi4l_uart_slave is
  generic (
    BASE_ADDR : std_logic_vector(31 downto 0);
    HIGH_ADDR : std_logic_vector(31 downto 0);
    FIFO_SIZE : integer
  );
  port (

    -- AXI interface
    master_i : in  AXI4L_MASTER_TO_SLAVE;
    slave_o  : out AXI4L_SLAVE_TO_MASTER;

    -- sync
    rstn_i : in std_logic;
    clk_i  : in std_logic;

    -- serial interface
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic

  );
end entity;

architecture arch of axi4l_uart_slave is
  -- axi slave interface signals
  signal axislv_done_w  : std_logic;
  signal axislv_error_w : std_logic;
  signal axislv_rdata_w : std_logic_vector(31 downto 0);
  signal axislv_wr_en_w : std_logic;
  signal axislv_rd_en_w : std_logic;
  signal axislv_addr_w  : std_logic_vector(31 downto 0);
  signal axislv_prot_w  : std_logic_vector(2 downto 0);
  signal axislv_wdata_w : std_logic_vector(31 downto 0);
  signal axislv_strb_w  : std_logic_vector(3 downto 0);

  -- addresses
  constant UART_IP_ADDR      : std_logic_vector(31 downto 0) := x"00000000";
  constant BAUD_DIV_REG_ADDR : std_logic_vector(31 downto 0) := x"00000004";
  constant PARITY_REG_ADDR   : std_logic_vector(31 downto 0) := x"00000008";
  constant RTSCTS_REG_ADDR   : std_logic_vector(31 downto 0) := x"0000000C";
  constant STATUS_ADDR       : std_logic_vector(31 downto 0) := x"00000010";

  -- address comparators
  signal axi_uart_addr_w     : std_logic;
  signal axi_baud_div_addr_w : std_logic;
  signal axi_parity_addr_w   : std_logic;
  signal axi_rtscts_addr_w   : std_logic;
  signal axi_status_addr_w   : std_logic;

  -- slave status info
  signal slv_status_w : std_logic_vector(31 downto 0);

  -- AXI UART configuration register
  signal baud_div_r : std_logic_vector(15 downto 0);
  signal parity_r   : std_logic;
  signal rtscts_r   : std_logic;

  -- UART transmit interface
  signal uart_tstart_w : std_logic;
  signal uart_tdata_r  : std_logic_vector(7 downto 0);
  signal uart_tdone_w  : std_logic;
  signal uart_tready_w : std_logic;
  -- UART receive interface
  signal uart_rdone_w : std_logic;
  signal uart_rdata_w : std_logic_vector(7 downto 0);
  signal uart_rerr_w  : std_logic;

  -- UART receive FIFO
  signal rfifo_read_w  : std_logic;
  signal rfifo_empty_w : std_logic;
  signal rfifo_full_w  : std_logic;
  signal rfifo_valid_w : std_logic;
  signal rfifo_rdata_w : std_logic_vector(7 downto 0);
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
    wr_ready_i => '1',
    rd_ready_i => '1',
    done_i     => axislv_done_w,
    error_i    => axislv_error_w,
    rdata_i    => axislv_rdata_w,
    wr_en_o    => axislv_wr_en_w,
    rd_en_o    => axislv_rd_en_w,
    addr_o     => axislv_addr_w,
    prot_o     => axislv_prot_w,
    wdata_o    => axislv_wdata_w,
    strb_o     => axislv_strb_w
  );

  -- address comparator
  axi_uart_addr_w     <= '1' when axislv_addr_w = UART_IP_ADDR      else '0';
  axi_baud_div_addr_w <= '1' when axislv_addr_w = BAUD_DIV_REG_ADDR else '0';
  axi_parity_addr_w   <= '1' when axislv_addr_w = PARITY_REG_ADDR   else '0';
  axi_rtscts_addr_w   <= '1' when axislv_addr_w = RTSCTS_REG_ADDR   else '0';
  axi_status_addr_w   <= '1' when axislv_addr_w = STATUS_ADDR       else '0';

  axislv_done_w <= rfifo_valid_w when axi_uart_addr_w = '1' and axislv_rd_en_w = '1' else
                   '1';
                   -- '1'           when axi_uart_addr_w = '0' else
                   -- rfifo_valid_w when axislv_rd_en_w  = '1' else
                   -- uart_tdone_w  when axislv_wr_en_w  = '1' else
                   -- '0';
  axislv_error_w <= '1' when axi_uart_addr_w = '1' and axislv_wr_en_w = '1' and uart_tready_w = '0' else
                    '1' when axi_uart_addr_w = '1' and axislv_rd_en_w = '1' and rfifo_empty_w = '1' and rfifo_valid_w = '0' else
                    '0';

  axislv_rdata_w <= x"000000"  & rfifo_rdata_w    when axi_uart_addr_w     = '1' else
                    x"0000"    & baud_div_r       when axi_baud_div_addr_w = '1' else
                    x"0000000" & "000" & parity_r when axi_parity_addr_w   = '1' else
                    x"0000000" & "000" & rtscts_r when axi_rtscts_addr_w   = '1' else
                    slv_status_w                  when axi_status_addr_w   = '1' else
                    x"deadbeef";

  slv_status_w(0) <= rfifo_empty_w;
  slv_status_w(1) <= not uart_tready_w;
  slv_status_w(31 downto 2) <= (others => '0');

  registers_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      baud_div_r   <= x"01B2"; --(others => '0');
      parity_r     <= '0';
      rtscts_r     <= '0';
    elsif rising_edge(clk_i) then
      if axislv_wr_en_w = '1' then
        -- baud div register
        if axi_baud_div_addr_w = '1' then
          baud_div_r <= axislv_wdata_w(15 downto 0);
        -- parity bit register
        elsif axi_parity_addr_w = '1' then
          parity_r <= axislv_wdata_w(0);
        -- rtscts flow control
        elsif axi_rtscts_addr_w = '1' then
          rtscts_r <= axislv_wdata_w(0);
        end if;
      end if;
    end if;
  end process;

  -- UART interface
  uart_tstart_w <= axislv_wr_en_w and axi_uart_addr_w and uart_tready_w;
  uart_tdata_p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if uart_tstart_w = '1' then
        uart_tdata_r <= axislv_wdata_w(7 downto 0);
      end if;
    end if;
  end process;

  uart_u : entity work.uart
  port map (
    -- configuration
    baud_div_i => baud_div_r,
    parity_i   => parity_r,
    rtscts_i   => rtscts_r,
    -- transmit
    tstart_i   => uart_tstart_w,
    tdata_i    => uart_tdata_r,
    tready_o   => uart_tready_w,
    tdone_o    => uart_tdone_w,
    -- receive
    rready_i   => not rfifo_full_w,
    rdone_o    => uart_rdone_w,
    rdata_o    => uart_rdata_w,
    rerr_o     => uart_rerr_w,
    -- sync
    rstn_i     => rstn_i,
    clk_i      => clk_i,
    -- uart
    uart_tx_o  => uart_tx_o,
    uart_rx_i  => uart_rx_i,
    uart_cts_i => uart_cts_i,
    uart_rts_o => uart_rts_o
  );

  rfifo_read_w <= axislv_rd_en_w and axi_uart_addr_w and (not rfifo_empty_w) and (not rfifo_valid_w);

  rec_fifo_u : entity work.fifo
  generic map (
    FIFO_SIZE  => FIFO_SIZE,
    DATA_WIDTH => 8
  )
  port map (
    write_i => uart_rdone_w and not rfifo_full_w,
    data_i  => uart_rdata_w,
    read_i  => rfifo_read_w,
    clk_i   => clk_i,
    rstn_i  => rstn_i,
    full_o  => rfifo_full_w,
    empty_o => rfifo_empty_w,
    valid_o => rfifo_valid_w,
    data_o  => rfifo_rdata_w
  );

end architecture;
