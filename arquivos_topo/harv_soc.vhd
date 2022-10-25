library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;

library work;
use work.harv_pkg.all;
use work.axi4l_pkg.all;
use work.memory_pkg.all;
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
    
    ext_event_i     : in  std_logic

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
  signal harv_hard_dmem_w : std_logic;
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

  signal mem_ev_rdata_valid_w : std_logic;
  signal mem_ev_sb_error_w    : std_logic;
  signal mem_ev_db_error_w    : std_logic;
  signal mem_ev_error_addr_w  : std_logic_vector(31 downto 0);
  signal mem_ev_ecc_addr_w    : std_logic_vector(31 downto 0);
  signal mem_ev_enc_data_w    : std_logic_vector(38 downto 0);
  signal mem_ev_event_w       : std_logic;

  signal clr_ext_event_w : std_logic;

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

  -------------------------------------------------------------------
  ------------------------- RESET controller ------------------------
  -------------------------------------------------------------------

  reset_controller_u : entity work.reset_controller
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

  -------------------------------------------------------------------
  ----------------------- HARV processor core -----------------------
  -------------------------------------------------------------------

  harv_u : harv
  generic map (
    PROGRAM_START_ADDR => PROGRAM_START_ADDR,
    TMR_CONTROL => HARV_TMR,
    TMR_ALU     => HARV_TMR,
    TMR_CSR     => HARV_TMR,
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
    hard_dmem_o  => harv_hard_dmem_w,
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
    clr_ext_event_o  => clr_ext_event_w,
    ext_event_i      => ext_event_i or mem_ev_event_w,
    periph_timeout_i => axi4l_timeout_w
  );
  hard_dmem_o <= harv_hard_dmem_w;
  clr_ext_event_o <= clr_ext_event_w;

  -------------------------------------------------------------------
  ----------------------- MEMORY INTERCONNECT -----------------------
  -------------------------------------------------------------------

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

  -------------------------------------------------------------------
  --------------------------- DATA MEMORY ---------------------------
  -------------------------------------------------------------------
  
  -- no data memory
  disabled_dmem_g : if not ENABLE_DMEM generate
    mem0_gnt_w     <= '0';
    mem0_err_w     <= '1';
    mem0_rdata_w   <= x"deadbeef";
    mem_ev_event_w <= '0';
  end generate;
  -- Data memory without ECC
  enable_dmem_g : if ENABLE_DMEM and not ENABLE_DMEM_ECC generate
    unaligned_memory_u : unaligned_memory
    generic map (
      BASE_ADDR    => DMEM_BASE_ADDR,
      HIGH_ADDR    => DMEM_HIGH_ADDR,
      SIM_INIT_AHX => FALSE,
      AHX_FILEPATH => ""
    )
    port map (
      rstn_i       => periph_rstn_w,
      clk_i        => clk_i,
      s_wr_ready_o => open,
      s_rd_ready_o => open,
      s_wr_en_i    => mem0_wren_w,
      s_rd_en_i    => mem0_rden_w,
      s_done_o     => mem0_gnt_w,
      s_error_o    => mem0_err_w,
      s_addr_i     => mem0_addr_w,
      s_wdata_i    => mem0_wdata_w,
      s_wstrb_i    => mem0_wstrb_w,
      s_rdata_o    => mem0_rdata_w
    );
    mem_ev_event_w <= '0';
  end generate;

  -- Data memory with ECC
  enable_ecc_dmem_g : if ENABLE_DMEM and ENABLE_DMEM_ECC generate
  begin
    unaligned_ecc_memory_u : entity work.unaligned_ecc_memory
    generic map (
      BASE_ADDR    => DMEM_BASE_ADDR,
      HIGH_ADDR    => DMEM_HIGH_ADDR,
      SIM_INIT_AHX => FALSE,
      AHX_FILEPATH => ""
    )
    port map (
      rstn_i           => periph_rstn_w,
      clk_i            => clk_i,
      correct_error_i  => harv_hard_dmem_w,
      s_wr_ready_o     => open,
      s_rd_ready_o     => open,
      s_wr_en_i        => mem0_wren_w,
      s_rd_en_i        => mem0_rden_w,
      s_done_o         => mem0_gnt_w,
      s_error_o        => mem0_err_w,
      s_addr_i         => mem0_addr_w,
      s_wdata_i        => mem0_wdata_w,
      s_wstrb_i        => mem0_wstrb_w,
      s_rdata_o        => mem0_rdata_w,
      -- event handling
      ev_rdata_valid_o => mem_ev_rdata_valid_w,
      ev_sb_error_o    => mem_ev_sb_error_w,
      ev_db_error_o    => mem_ev_db_error_w,
      ev_error_addr_o  => mem_ev_error_addr_w,
      ev_ecc_addr_o    => mem_ev_ecc_addr_w,
      ev_enc_data_o    => mem_ev_enc_data_w
    );
    mem_ev_event_w <= '0';
    -- -- TODO: connect event handler to AMBA
    -- axi4l_mem_event_handler_u : axi4l_mem_event_handler
    -- generic map (
    --   BASE_ADDR => std_logic_vector(unsigned(DMEM_HIGH_ADDR)+1),
    --   HIGH_ADDR => std_logic_vector(unsigned(DMEM_HIGH_ADDR)+16#1F#)
    -- )
    -- port map (
    --   rstn_i            => periph_rstn_w,
    --   clk_i             => clk_i,
    --   master_i          => master_i,
    --   slave_o           => slave_o,
    --   mem_rdata_valid_i => mem_ev_rdata_valid_w,
    --   mem_sbu_i         => mem_ev_sb_error_w,
    --   mem_dbu_i         => mem_ev_db_error_w,
    --   mem_addr_i        => mem_ev_error_addr_w,
    --   mem_ecc_addr_i    => mem_ev_ecc_addr_w,
    --   mem_enc_data_i    => mem_ev_enc_data_w,
    --   clear_i           => clr_ext_event_w,
    --   event_o           => mem_ev_event_w
    -- );
  end generate;

  -------------------------------------------------------------------
  --------------------------- PERIPHERALS ---------------------------
  -------------------------------------------------------------------
  
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
    -- sync
    ext_rstn_i      => ext_rstn_w,
    periph_rstn_i   => periph_rstn_w,
    clk_i           => clk_i,
    -- processor local interface
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
    -- UART
    uart_rx_i       => uart_rx_i,
    uart_tx_o       => uart_tx_o,
    uart_rts_o      => uart_rts_o,
    uart_cts_i      => uart_cts_i,
    -- WDT reset
    wdt_rstn_o      => wdt_rstn_w,
    -- GPIO
    tri_o           => gpio_tri_o,
    rports_i        => gpio_rd_i,
    wports_o        => gpio_wr_o,
    -- AXI4-lite slave interface
    axi4l_master_o  => axi4l_master_o,
    axi4l_slave_i   => axi4l_slave_i
  );

end architecture;
