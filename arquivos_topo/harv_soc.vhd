library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;

library work;
use work.harv_pkg.all;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.all;

entity harv_soc is
  generic (
    -- HARV parameters
    PROGRAM_START_ADDR : std_logic_vector(31 downto 0) := x"00000000";
    HARV_TMR : boolean := FALSE;
    HARV_ECC : boolean := FALSE;
    -- SoC parameters
    ENABLE_ROM      : boolean                       := TRUE;
    ENABLE_DMEM     : boolean                       := TRUE;
    ENABLE_DMEM_ECC : boolean                       := FALSE;
    DMEM_BASE_ADDR  : std_logic_vector(31 downto 0) := x"08000000";
    DMEM_HIGH_ADDR  : std_logic_vector(31 downto 0) := x"08000FFF";
    -- GPIO peripheral parameter
    GPIO_SIZE : integer := 13
  );
  port (
    -- sync
    poweron_rstn_i : in  std_logic;
    btn_rstn_i     : in  std_logic;
    clk_i          : in  std_logic;
    start_i        : in  std_logic;
    periph_rstn_o  : out std_logic;

    -- UART
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic;

    -- GPIO
    gpio_tri_o : out std_logic_vector(GPIO_SIZE-1 downto 0);
    gpio_rd_i  : in  std_logic_vector(GPIO_SIZE-1 downto 0);
    gpio_wr_o  : out std_logic_vector(GPIO_SIZE-1 downto 0);

    -- AXI4-lite slave interface
    axi4l_master_o : out AXI4L_MASTER_TO_SLAVE;
    axi4l_slave_i  : in  AXI4L_SLAVE_TO_MASTER;

    ext_event_i : in std_logic

  );
end entity;


architecture arch of harv_soc is
  -- reset signals
  signal ext_rstn_w    : std_logic;
  signal proc_rstn_w   : std_logic;
  signal periph_rstn_w : std_logic;
  signal wdt_rstn_w    : std_logic;

  -- instruction memory interface
  signal harv_imem_rden_w  : std_logic;
  signal harv_imem_addr_w  : std_logic_vector(31 downto 0);
  signal harv_imem_gnt_w   : std_logic;
  signal harv_imem_err_w   : std_logic;
  signal harv_imem_rdata_w : std_logic_vector(31 downto 0);

  -- hardening
  -- data memory interface
  signal harv_dmem_wren_w   : std_logic;
  signal harv_dmem_rden_w   : std_logic;
  signal harv_dmem_gnt_w    : std_logic;
  signal harv_dmem_err_w    : std_logic;
  signal harv_dmem_addr_w   : std_logic_vector(31 downto 0);
  signal harv_dmem_wdata_w  : std_logic_vector(31 downto 0);
  signal harv_dmem_wstrb_w  : std_logic_vector(3 downto 0);
  signal harv_dmem_rdata_w  : std_logic_vector(31 downto 0);

  -- mem 0 interface
  signal mem0_wren_w   : std_logic;
  signal mem0_rden_w   : std_logic;
  signal mem0_gnt_w    : std_logic;
  signal mem0_err_w    : std_logic;
  signal mem0_prot_w   : std_logic_vector(2 downto 0);
  signal mem0_addr_w   : std_logic_vector(31 downto 0);
  signal mem0_wdata_w  : std_logic_vector(31 downto 0);
  signal mem0_wstrb_w  : std_logic_vector(3 downto 0);
  signal mem0_rdata_w  : std_logic_vector(31 downto 0);

  -- mem 1 interface
  signal mem1_wren_w   : std_logic;
  signal mem1_rden_w   : std_logic;
  signal mem1_gnt_w    : std_logic;
  signal mem1_err_w    : std_logic;
  signal mem1_prot_w   : std_logic_vector(2 downto 0);
  signal mem1_addr_w   : std_logic_vector(31 downto 0);
  signal mem1_wdata_w  : std_logic_vector(31 downto 0);
  signal mem1_wstrb_w  : std_logic_vector(3 downto 0);
  signal mem1_rdata_w  : std_logic_vector(31 downto 0);

  signal axi4l_timeout_w : std_logic;

begin

  reset_controller_inst : entity work.reset_controller
  port map (
    clk_i          => clk_i,
    -- reset input
    poweron_rstn_i   => poweron_rstn_i,
    btn_rstn_i       => btn_rstn_i,
    wdt_rstn_i       => wdt_rstn_w,
    periph_timeout_i => axi4l_timeout_w,
    -- reset output
    ext_rstn_o        => ext_rstn_w,
    proc_rstn_o       => proc_rstn_w,
    periph_rstn_o     => periph_rstn_w,
    ext_periph_rstn_o => periph_rstn_o
  );

  harv_u : harv
  generic map (
    PROGRAM_START_ADDR => PROGRAM_START_ADDR,
    TMR_CONTROL => HARV_TMR,
    TMR_ALU     => HARV_TMR,
    ECC_REGFILE => HARV_ECC,
    ECC_PC      => HARV_ECC
  )
  port map (
    rstn_i  => proc_rstn_w,
    clk_i   => clk_i,
    start_i => start_i,
    -- RESET CAUSE
    poweron_rstn_i => poweron_rstn_i,
    wdt_rstn_i     => wdt_rstn_w,
    -- INSTRUCTION MEMORY
    imem_rden_o  => harv_imem_rden_w,
    imem_gnt_i   => harv_imem_gnt_w,
    imem_err_i   => harv_imem_err_w,
    imem_addr_o  => harv_imem_addr_w,
    imem_rdata_i => harv_imem_rdata_w,
    -- DATA MEMORY
    dmem_wren_o  => harv_dmem_wren_w,
    dmem_rden_o  => harv_dmem_rden_w,
    dmem_gnt_i   => harv_dmem_gnt_w,
    dmem_err_i   => harv_dmem_err_w,
    dmem_addr_o  => harv_dmem_addr_w,
    dmem_wdata_o => harv_dmem_wdata_w,
    dmem_wstrb_o => harv_dmem_wstrb_w,
    dmem_rdata_i => harv_dmem_rdata_w,
    -- interrupt
    ext_interrupt_i  => x"00",
    ext_event_i      => ext_event_i,
    periph_timeout_i => axi4l_timeout_w
  );

  mem_interconnect_u : entity work.mem_interconnect
  generic map (
    MEM0_BASE_ADDR => DMEM_BASE_ADDR,
    MEM0_HIGH_ADDR => DMEM_HIGH_ADDR
  )
  port map (
    -- instruction memory interface
    imem_rden_i  => harv_imem_rden_w,
    imem_gnt_o   => harv_imem_gnt_w,
    imem_err_o   => harv_imem_err_w,
    imem_addr_i  => harv_imem_addr_w,
    imem_rdata_o => harv_imem_rdata_w,
    -- data memory interface
    dmem_wren_i   => harv_dmem_wren_w,
    dmem_rden_i   => harv_dmem_rden_w,
    dmem_gnt_o    => harv_dmem_gnt_w,
    dmem_err_o    => harv_dmem_err_w,
    dmem_addr_i   => harv_dmem_addr_w,
    dmem_wdata_i  => harv_dmem_wdata_w,
    dmem_wstrb_i  => harv_dmem_wstrb_w,
    dmem_rdata_o  => harv_dmem_rdata_w,
    -- mem 0 interface
    mem0_wren_o   => mem0_wren_w,
    mem0_rden_o   => mem0_rden_w,
    mem0_gnt_i    => mem0_gnt_w,
    mem0_err_i    => mem0_err_w,
    mem0_prot_o   => mem0_prot_w,
    mem0_addr_o   => mem0_addr_w,
    mem0_wdata_o  => mem0_wdata_w,
    mem0_wstrb_o  => mem0_wstrb_w,
    mem0_rdata_i  => mem0_rdata_w,
    -- mem 1 interface
    mem1_wren_o   => mem1_wren_w,
    mem1_rden_o   => mem1_rden_w,
    mem1_gnt_i    => mem1_gnt_w,
    mem1_err_i    => mem1_err_w,
    mem1_prot_o   => mem1_prot_w,
    mem1_addr_o   => mem1_addr_w,
    mem1_wdata_o  => mem1_wdata_w,
    mem1_wstrb_o  => mem1_wstrb_w,
    mem1_rdata_i  => mem1_rdata_w
  );

  enable_dmem_g : if ENABLE_DMEM generate
  begin
--    enable_dmem_ecc_g : if ENABLE_DMEM_ECC generate
--      unaligned_ecc_memory_u : entity work.unaligned_ecc_memory
--      generic map (
--        BASE_ADDR => DMEM_BASE_ADDR,
--        HIGH_ADDR => DMEM_HIGH_ADDR
--      )
--      port map (
--        rstn_i        => periph_rstn_w,
--        clk_i         => clk_i,
--        s_wr_ready_o  => open,
--        s_rd_ready_o  => open,
--        s_wr_en_i     => mem0_req_w and mem0_wren_w,
--        s_rd_en_i     => mem0_req_w and not mem0_wren_w,
--        s_done_o      => mem0_gnt_w,
--        s_error_o     => mem0_err_w,
--        s_addr_i      => mem0_addr_w,
--        s_wdata_i     => mem0_wdata_w,
--        s_wstrb_i     => mem0_b,
--        s_rdata_o     => mem_rdata_w,
--        -- events information
--        rdata_valid_o => rdata_valid_o,
--        sb_error_o    => sb_error_o,
--        db_error_o    => db_error_o,
--        error_addr_o  => error_addr_o,
--        ecc_addr_o    => ecc_addr_o,
--        enc_data_o    => enc_data_o
--      );

--    else generate
--      unaligned_memory_u : entity work.unaligned_memory
--      generic map (
--        BASE_ADDR     => x"00000000",
--        HIGH_ADDR     => std_logic_vector(to_unsigned(SIZE-1, 32))
--      )
--      port map (
--        rstn_i       => periph_rstn_w,
--        clk_i        => clk_i,
--        s_wr_ready_o => open,
--        s_rd_ready_o => open,
--        s_wr_en_i    => mem0_req_w and mem0_wren_w,
--        s_rd_en_i    => mem0_req_w and not mem0_wren_w,
--        s_done_o     => mem0_gnt_w,
--        s_error_o    => mem0_err_w,
--        s_addr_i     => mem_addr_w,
--        s_wdata_i    => mem_wdata_w,
--        s_wstrb_i    => mem_wstrb_w,
--        s_rdata_o    => mem_rdata_w
--      );
--      rdata_valid_o <= '0';
--      sb_error_o    <= '0';
--      db_error_o    <= '0';
--      error_addr_o  <= (others => '0');
--      ecc_addr_o    <= (others => '0');
--      enc_data_o    <= (others => '0');
--    end generate;
    -- mem_unaligned_adapter_u : mem_unaligned_adapter
    -- port map (
    --   rstn_i       => periph_rstn_w,
    --   clk_i        => clk_i,
    --   s_wr_ready_o => s_wr_ready_o,
    --   s_rd_ready_o => s_rd_ready_o,
    --   s_wr_en_i    => s_wr_en_i,
    --   s_rd_en_i    => s_rd_en_i,
    --   s_done_o     => s_done_o,
    --   s_error_o    => s_error_o,
    --   s_addr_i     => s_addr_i,
    --   s_wdata_i    => s_wdata_i,
    --   s_wstrb_i    => s_wstrb_i,
    --   s_rdata_o    => s_rdata_o,
    --   m_wr_ready_i => m_wr_ready_i,
    --   m_rd_ready_i => m_rd_ready_i,
    --   m_wr_en_o    => m_wr_en_o,
    --   m_rd_en_o    => m_rd_en_o,
    --   m_done_i     => m_done_i,
    --   m_error_i    => m_error_i,
    --   m_addr_o     => m_addr_o,
    --   m_wdata_o    => m_wdata_o,
    --   m_rdata_i    => m_rdata_i
    -- );
    -- enable_dmem_ecc_g : if i generate
    --
    -- end generate;
    -- data_mem_u : entity work.memory
    -- generic map (
    --   DETECT_DOUBLE => TRUE,
    --   BASE_ADDR => DMEM_BASE_ADDR,
    --   HIGH_ADDR => DMEM_HIGH_ADDR
    -- )
    -- port map (
    --   hard_i       => harv_dmem_hard_w,
    --   req_i        => mem0_req_w,
    --   wren_i       => mem0_wren_w,
    --   ben_i        => mem0_ben_w,
    --   usgn_i       => mem0_usgn_w,
    --   addr_i       => mem0_addr_w,
    --   data_i       => mem0_wdata_w,
    --   rstn_i       => rstn_w,
    --   clk_i        => clk_i,
    --   gnt_o        => mem0_gnt_w,
    --   outofrange_o => mem0_err_w,
    --   upsets_o     => mem0_upsets_w,
    --   data_o       => mem0_rdata_w
    -- );
  else generate
    mem0_gnt_w    <= '0';
    mem0_err_w    <= '1';
    mem0_rdata_w  <= x"deadbeef";
  end generate;

  axi4l_top_u : entity work.axi4l_top
  generic map (
    ENABLE_ROM     => ENABLE_ROM,
    ROM_BASE_ADDR  => x"00000000",
    ROM_HIGH_ADDR  => x"00000FFF",
    UART_BASE_ADDR => x"80000000",
    UART_HIGH_ADDR => x"8000001F",
    WDT_BASE_ADDR  => x"80000100",
    WDT_HIGH_ADDR  => x"80000103",
    GPIO_BASE_ADDR => x"80000200",
    GPIO_HIGH_ADDR => x"80000207",
    GPIO_SIZE      => GPIO_SIZE
  )
  port map (
    -- processor
    wren_i  => mem1_wren_w,
    rden_i  => mem1_rden_w,
    gnt_o   => mem1_gnt_w,
    err_o   => mem1_err_w,
    prot_i  => mem1_prot_w,
    addr_i  => mem1_addr_w,
    wdata_i => mem1_wdata_w,
    wstrb_i => mem1_wstrb_w,
    rdata_o => mem1_rdata_w,
    -- event
    axi4l_timeout_o => axi4l_timeout_w,
    -- sync
    ext_rstn_i    => ext_rstn_w,
    periph_rstn_i => periph_rstn_w,
    clk_i         => clk_i,
    -- UART
    uart_rx_i  => uart_rx_i,
    uart_tx_o  => uart_tx_o,
    uart_cts_i => uart_cts_i,
    uart_rts_o => uart_rts_o,
    -- WDT reset
    wdt_rstn_o => wdt_rstn_w,
    -- GPIO
    tri_o    => gpio_tri_o,
    rports_i => gpio_rd_i,
    wports_o => gpio_wr_o,
    -- AXI4-lite slave interface
    axi4l_master_o => axi4l_master_o,
    axi4l_slave_i  => axi4l_slave_i
  );

end architecture;
