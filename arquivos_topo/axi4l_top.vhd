library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.all;

entity axi4l_top is
  generic (
    ENABLE_ROM     : boolean;
    ROM_BASE_ADDR  : std_logic_vector(31 downto 0);
    ROM_HIGH_ADDR  : std_logic_vector(31 downto 0);
    UART_BASE_ADDR : std_logic_vector(31 downto 0);
    UART_HIGH_ADDR : std_logic_vector(31 downto 0);
    WDT_BASE_ADDR  : std_logic_vector(31 downto 0);
    WDT_HIGH_ADDR  : std_logic_vector(31 downto 0);
    GPIO_BASE_ADDR : std_logic_vector(31 downto 0);
    GPIO_HIGH_ADDR : std_logic_vector(31 downto 0);
    GPIO_SIZE      : integer
  );
  port (
    ----------------- SYSTEM interface ----------------
    wren_i  : in  std_logic;
    rden_i  : in  std_logic;
    gnt_o   : out std_logic;
    err_o   : out std_logic;
    prot_i  : in  std_logic_vector(2 downto 0);
    addr_i  : in  std_logic_vector(31 downto 0);
    wdata_i : in  std_logic_vector(31 downto 0);
    wstrb_i : in  std_logic_vector(3 downto 0);
    rdata_o : out std_logic_vector(31 downto 0);

    -- event
    axi4l_timeout_o : out std_logic;

    -- sync
    ext_rstn_i    : in std_logic;
    periph_rstn_i : in std_logic;
    clk_i         : in std_logic;

    ----------------- Peripherals ----------------

    -- UART
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic;

    -- WDT
    wdt_rstn_o : out std_logic;

    -- GPIO
    tri_o    : out std_logic_vector(GPIO_SIZE-1 downto 0);
    rports_i : in  std_logic_vector(GPIO_SIZE-1 downto 0);
    wports_o : out std_logic_vector(GPIO_SIZE-1 downto 0);

    -- AXI4-lite slave interface
    axi4l_master_o : out AXI4L_MASTER_TO_SLAVE;
    axi4l_slave_i  : in  AXI4L_SLAVE_TO_MASTER

  );
end entity;

architecture arch of axi4l_top is

  -- BUS MASTER INTERFACE
  signal axi_master2slaves_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slaves2master_w : AXI4L_SLAVE_TO_MASTER;

  -- AXI SLAVE INTERCONNECTIONS
  -- slave 0
  signal axi_slave0_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave0_slave_w  : AXI4L_SLAVE_TO_MASTER;
  -- slave 1
  signal axi_slave1_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave1_slave_w  : AXI4L_SLAVE_TO_MASTER;
  -- slave 2
  signal axi_slave2_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave2_slave_w  : AXI4L_SLAVE_TO_MASTER;
  -- slave 3
  signal axi_slave3_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave3_slave_w  : AXI4L_SLAVE_TO_MASTER;
  
  -- slave 4
  signal axi_slave4_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave4_slave_w  : AXI4L_SLAVE_TO_MASTER;
  
    -- slave 5
  signal axi_slave5_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave5_slave_w  : AXI4L_SLAVE_TO_MASTER;
  
  -- slave 6
  signal axi_slave6_master_w : AXI4L_MASTER_TO_SLAVE;
  signal axi_slave6_slave_w  : AXI4L_SLAVE_TO_MASTER;

begin

  axi4l_master_u : axi4l_master
  port map (
    rstn_i    => periph_rstn_i,
    clk_i     => clk_i,
    -- local interface
    wren_i    => wren_i,
    rden_i    => rden_i,
    gnt_o     => gnt_o,
    err_o     => err_o,
    prot_i    => prot_i,
    addr_i    => addr_i,
    wdata_i   => wdata_i,
    wstrb_i   => wstrb_i,
    rdata_o   => rdata_o,
    -- amba interface
    slave_i   => axi_slaves2master_w,
    master_o  => axi_master2slaves_w,
    -- event
    timeout_o => axi4l_timeout_o
  );

  axi4l_interconnect_u : entity work.axi4l_interconnect_4
  generic map (
    SLAVE0_BASE_ADDR => ROM_BASE_ADDR,
    SLAVE0_HIGH_ADDR => ROM_HIGH_ADDR,
    SLAVE1_BASE_ADDR => UART_BASE_ADDR,
    SLAVE1_HIGH_ADDR => UART_HIGH_ADDR,
    SLAVE2_BASE_ADDR => WDT_BASE_ADDR,
    SLAVE2_HIGH_ADDR => WDT_HIGH_ADDR,
    SLAVE3_BASE_ADDR => GPIO_BASE_ADDR,
    SLAVE3_HIGH_ADDR => GPIO_HIGH_ADDR
  )
  port map (
    rstn_i => periph_rstn_i,
    clk_i  => clk_i,
    -- master
    master_i => axi_master2slaves_w,
    slave_o  => axi_slaves2master_w,
    -- slave 0
    master0_o => axi_slave0_master_w,
    slave0_i  => axi_slave0_slave_w,
    -- slave 1
    master1_o => axi_slave1_master_w,
    slave1_i  => axi_slave1_slave_w,
    -- slave 2
    master2_o => axi_slave2_master_w,
    slave2_i  => axi_slave2_slave_w,
    -- slave 3
    master3_o => axi_slave3_master_w,
    slave3_i  => axi_slave3_slave_w,
    -- external slave
    ext_master_o => axi4l_master_o,
    ext_slave_i  => axi4l_slave_i
  );

  enable_rom_g : if ENABLE_ROM generate
    axi4l_rom_slave_u : axi4l_rom_slave
    generic map (
      BASE_ADDR => ROM_BASE_ADDR,
      HIGH_ADDR => ROM_HIGH_ADDR
    )
    port map (
      rstn_i   => periph_rstn_i,
      clk_i    => clk_i,
      master_i => axi_slave0_master_w,
      slave_o  => axi_slave0_slave_w
    );
  else generate
    axi_slave0_slave_w <= AXI4L_S2M_DECERR;
  end generate;


  axi4l_uart_slave_u : axi4l_uart_slave
  generic map (
    BASE_ADDR => UART_BASE_ADDR,
    HIGH_ADDR => UART_HIGH_ADDR
  )
  port map (
    master_i   => axi_slave1_master_w,
    slave_o    => axi_slave1_slave_w,
    rstn_i     => periph_rstn_i,
    clk_i      => clk_i,
    uart_rx_i  => uart_rx_i,
    uart_tx_o  => uart_tx_o,
    uart_cts_i => uart_cts_i,
    uart_rts_o => uart_rts_o
  );

  axi4l_wdt_slave_u : axi4l_wdt_slave
  generic map (
    BASE_ADDR   => WDT_BASE_ADDR,
    HIGH_ADDR   => WDT_HIGH_ADDR
  )
  port map (
    master_i      => axi_slave2_master_w,
    slave_o       => axi_slave2_slave_w,
    ext_rstn_i    => ext_rstn_i,
    periph_rstn_i => periph_rstn_i,
    clk_i         => clk_i,
    wdt_rstn_o    => wdt_rstn_o
  );

  axi4l_gpio_slave_u : axi4l_gpio_slave
  generic map (
    BASE_ADDR => GPIO_BASE_ADDR,
    HIGH_ADDR => GPIO_HIGH_ADDR,
    GPIO_SIZE => GPIO_SIZE
  )
  port map (
    master_i => axi_slave3_master_w,
    slave_o  => axi_slave3_slave_w,
    rstn_i   => periph_rstn_i,
    clk_i    => clk_i,
    tri_o    => tri_o,
    rports_i => rports_i,
    wports_o => wports_o
  );

end architecture;
