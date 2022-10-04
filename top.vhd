library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;

library work;
use work.harv_pkg.all;
use work.axi4l_pkg.all;


entity harv_soc is
  generic (
    GPIO_SIZE            :  integer := x"00000000"
  );
  port (
    poweron_rstn_i   :  in   std_logic;
    btn_rstn_i       :  in   std_logic;
    clk_i            :  in   std_logic;
    start_i          :  in   std_logic;
    periph_rstn_o    :  out  std_logic;
    uart_rx_i        :  in   std_logic;
    uart_tx_o        :  out  std_logic;
    uart_cts_i       :  in   std_logic;
    uart_rts_o       :  out  std_logic;
    gpio_tri_o       :  out  std_logic_vector(GPIO_SIZE-1 downto 0);
    gpio_rd_i        :  in   std_logic_vector(GPIO_SIZE-1 downto 0);
    gpio_wr_o        :  out  std_logic_vector(GPIO_SIZE-1 downto 0);
    axi4l_master_o   :  out  AXI4L_MASTER_TO_SLAVE;
    axi4l_slave_i    :  in   AXI4L_SLAVE_TO_MASTER;
    ext_event_i      :  in   std_logic
  );
end entity;

architecture arch of harv_soc is 
  constant PROGRAM_START_ADDR  :  std_logic_vector(31 downto 0) := x"00000000";
  constant HARV_TMR            :  boolean := FALSE;
  constant HARV_ECC            :  boolean := FALSE;
  constant ENABLE_ROM          :  boolean := TRUE;
  constant ENABLE_DMEM         :  boolean := TRUE;
  constant ENABLE_DMEM_ECC     :  boolean := FALSE;
  constant DMEM_BASE_ADDR      :  std_logic_vector(31 downto 0) := x"00000000";
  constant DMEM_HIGH_ADDR      :  std_logic_vector(31 downto 0) := x"00000000";
  signal ext_rstn_w            :  std_logic;
  signal proc_rstn_w           :  std_logic;
  signal periph_rstn_w         :  std_logic;
  signal wdt_rstn_w            :  std_logic;
  signal harv_imem_rden_w      :  std_logic;
  signal harv_imem_addr_w      :  std_logic_vector(31 downto 0);
  signal harv_imem_gnt_w       :  std_logic;
  signal harv_imem_err_w       :  std_logic;
  signal harv_imem_rdata_w     :  std_logic_vector(31 downto 0);
  signal harv_dmem_wren_w      :  std_logic;
  signal harv_dmem_rden_w      :  std_logic;
  signal harv_dmem_gnt_w       :  std_logic;
  signal harv_dmem_err_w       :  std_logic;
  signal harv_dmem_addr_w      :  std_logic_vector(31 downto 0);
  signal harv_dmem_wdata_w     :  std_logic_vector(31 downto 0);
  signal harv_dmem_wstrb_w     :  std_logic_vector(3 downto 0);
  signal harv_dmem_rdata_w     :  std_logic_vector(31 downto 0);
  signal mem0_wren_w           :  std_logic;
  signal mem0_rden_w           :  std_logic;
  signal mem0_gnt_w            :  std_logic;
  signal mem0_err_w            :  std_logic;
  signal mem0_prot_w           :  std_logic_vector(2 downto 0);
  signal mem0_addr_w           :  std_logic_vector(31 downto 0);
  signal mem0_wdata_w          :  std_logic_vector(31 downto 0);
  signal mem0_wstrb_w          :  std_logic_vector(3 downto 0);
  signal mem0_rdata_w          :  std_logic_vector(31 downto 0);
  signal mem1_wren_w           :  std_logic;
  signal mem1_rden_w           :  std_logic;
  signal mem1_gnt_w            :  std_logic;
  signal mem1_err_w            :  std_logic;
  signal mem1_prot_w           :  std_logic_vector(2 downto 0);
  signal mem1_addr_w           :  std_logic_vector(31 downto 0);
  signal mem1_wdata_w          :  std_logic_vector(31 downto 0);
  signal mem1_wstrb_w          :  std_logic_vector(3 downto 0);
  signal mem1_rdata_w          :  std_logic_vector(31 downto 0);
  signal axi4l_timeout_w       :  std_logic;
  signal axi_master2slaves_w   :  AXI4L_MASTER_TO_SLAVE;
  signal axi_slaves2master_w   :  AXI4L_SLAVE_TO_MASTER;
  signal axi_slave0_master_w   :  AXI4L_MASTER_TO_SLAVE;
  signal axi_slave0_slave_w    :  AXI4L_SLAVE_TO_MASTER;
  signal axi_slave1_master_w   :  AXI4L_MASTER_TO_SLAVE;
  signal axi_slave1_slave_w    :  AXI4L_SLAVE_TO_MASTER;
  signal axi_slave2_master_w   :  AXI4L_MASTER_TO_SLAVE;
  signal axi_slave2_slave_w    :  AXI4L_SLAVE_TO_MASTER;
  signal axi_slave3_master_w   :  AXI4L_MASTER_TO_SLAVE;
  signal axi_slave3_slave_w    :  AXI4L_SLAVE_TO_MASTER;
  signal axi_slave4_master_w   :  AXI4L_MASTER_TO_SLAVE;
  signal axi_slave4_slave_w    :  AXI4L_SLAVE_TO_MASTER;
  signal mem_ev_rdata_valid_w  :  std_logic;
  signal mem_ev_sb_error_w     :  std_logic;
  signal mem_ev_db_error_w     :  std_logic;
  signal mem_ev_error_addr_w   :  std_logic_vector(2 downto 0);
  signal mem_ev_ecc_addr_w     :  std_logic_vector(31 downto 0);
  signal mem_ev_enc_data_w     :  std_logic_vector(38 downto 0);
  signal mem_ev_event_w        :  std_logic;

begin 

  reset_controller_u   : entity work.reset_controller 
  port map ( 
    clk_i               =>  clk_i, 
    poweron_rstn_i      =>  poweron_rstn_i, 
    btn_rstn_i          =>  btn_rstn_i, 
    wdt_rstn_i          =>  wdt_rstn_w, 
    periph_timeout_i    =>  axi4l_timeout_w, 
    ext_rstn_o          =>  ext_rstn_w, 
    proc_rstn_o         =>  proc_rstn_w, 
    periph_rstn_o       =>  periph_rstn_w, 
    ext_periph_rstn_o   =>  periph_rstn_o
  );

  harv_u               : harv 
  generic map ( 
    program_start_addr  =>  PROGRAM_START_ADDR, 
    tmr_control         =>  HARV_TMR, 
    tmr_alu             =>  HARV_TMR, 
    ecc_regfile         =>  HARV_ECC, 
    ecc_pc              =>  HARV_ECC
  )
  port map ( 
    rstn_i              =>  proc_rstn_w, 
    clk_i               =>  clk_i, 
    start_i             =>  start_i, 
    poweron_rstn_i      =>  poweron_rstn_i, 
    wdt_rstn_i          =>  wdt_rstn_w, 
    imem_rden_o         =>  harv_imem_rden_w, 
    imem_gnt_i          =>  harv_imem_gnt_w, 
    imem_err_i          =>  harv_imem_err_w, 
    imem_addr_o         =>  harv_imem_addr_w, 
    imem_rdata_i        =>  harv_imem_rdata_w, 
    dmem_wren_o         =>  harv_dmem_wren_w, 
    dmem_rden_o         =>  harv_dmem_rden_w, 
    dmem_gnt_i          =>  harv_dmem_gnt_w, 
    dmem_err_i          =>  harv_dmem_err_w, 
    dmem_addr_o         =>  harv_dmem_addr_w, 
    dmem_wdata_o        =>  harv_dmem_wdata_w, 
    dmem_wstrb_o        =>  harv_dmem_wstrb_w, 
    dmem_rdata_i        =>  harv_dmem_rdata_w, 
    ext_interrupt_i     =>  x"00", 
    ext_event_i         =>  mem_ev_event_w, 
    periph_timeout_i    =>  0
  );

  mem_interconnect_u   : entity work.mem_interconnect 
  generic map ( 
    mem0_base_addr      =>  DMEM_BASE_ADDR, 
    mem0_high_addr      =>  DMEM_HIGH_ADDR
  )
  port map ( 
    imem_rden_i         =>  harv_imem_rden_w, 
    imem_addr_i         =>  harv_imem_addr_w, 
    imem_gnt_o          =>  harv_imem_gnt_w, 
    imem_err_o          =>  harv_imem_err_w, 
    imem_rdata_o        =>  harv_imem_rdata_w, 
    dmem_wren_i         =>  harv_dmem_wren_w, 
    dmem_rden_i         =>  harv_dmem_rden_w, 
    dmem_gnt_o          =>  harv_dmem_gnt_w, 
    dmem_err_o          =>  harv_dmem_err_w, 
    dmem_addr_i         =>  harv_dmem_addr_w, 
    dmem_wdata_i        =>  harv_dmem_wdata_w, 
    dmem_wstrb_i        =>  harv_dmem_wstrb_w, 
    dmem_rdata_o        =>  harv_dmem_rdata_w, 
    mem0_wren_o         =>  mem0_wren_w, 
    mem0_rden_o         =>  mem0_rden_w, 
    mem0_gnt_i          =>  mem0_gnt_w, 
    mem0_err_i          =>  mem0_err_w, 
    mem0_prot_o         =>  mem0_prot_w, 
    mem0_addr_o         =>  mem0_addr_w, 
    mem0_wdata_o        =>  mem0_wdata_w, 
    mem0_wstrb_o        =>  mem0_wstrb_w, 
    mem0_rdata_i        =>  mem0_rdata_w, 
    mem1_wren_o         =>  mem1_wren_w, 
    mem1_rden_o         =>  mem1_rden_w, 
    mem1_gnt_i          =>  mem1_gnt_w, 
    mem1_err_i          =>  mem1_err_w, 
    mem1_prot_o         =>  mem1_prot_w, 
    mem1_addr_o         =>  mem1_addr_w, 
    mem1_wdata_o        =>  mem1_wdata_w, 
    mem1_wstrb_o        =>  mem1_wstrb_w, 
    mem1_rdata_i        =>  mem1_rdata_w
  );

  axi4l_master_u       : axi4l_master 
  port map ( 
    wren_i              =>  mem1_wren_w, 
    rden_i              =>  mem1_rden_w, 
    gnt_o               =>  mem1_gnt_w, 
    err_o               =>  mem1_err_w, 
    prot_i              =>  mem1_prot_w, 
    addr_i              =>  mem1_addr_w, 
    wdata_i             =>  mem1_wdata_w, 
    wstrb_i             =>  mem1_wstrb_w, 
    rdata_o             =>  mem1_rdata_w, 
    rstn_i              =>  poweron_rstn_i, 
    clk_i               =>  clk_i, 
    slave_i             =>  axi_slaves2master_w, 
    master_o            =>  axi_master2slaves_w, 
    timeout_o           =>  open
  );

  axi4l_interconnect_5_u : axi4l_interconnect_5 
  generic map ( 
    slave0_base_addr    =>  x"00000000", 
    slave0_high_addr    =>  x"00000FFF", 
    slave1_base_addr    =>  x"80000000", 
    slave1_high_addr    =>  x"8000001F", 
    slave2_base_addr    =>  x"80000100", 
    slave2_high_addr    =>  x"80000103", 
    slave3_base_addr    =>  x"80000200", 
    slave3_high_addr    =>  x"80000207", 
    slave4_base_addr    =>  x"80000300", 
    slave4_high_addr    =>  x"80000303"
  )
  port map ( 
    rstn_i              =>  poweron_rstn_i, 
    clk_i               =>  clk_i, 
    master_i            =>  axi_master2slaves_w, 
    slave_o             =>  axi_slaves2master_w, 
    master0_o           =>  axi_slave0_master_w, 
    slave0_i            =>  axi_slave0_slave_w, 
    master1_o           =>  axi_slave1_master_w, 
    slave1_i            =>  axi_slave1_slave_w, 
    master2_o           =>  axi_slave2_master_w, 
    slave2_i            =>  axi_slave2_slave_w, 
    master3_o           =>  axi_slave3_master_w, 
    slave3_i            =>  axi_slave3_slave_w, 
    master4_o           =>  axi_slave4_master_w, 
    slave4_i            =>  axi_slave4_slave_w, 
    ext_master_o        =>  open, 
    ext_slave_i         =>  AXI4L_S2M_DECERR
  );

  axi4l_rom_slave_u    : axi4l_rom_slave 
  generic map ( 
    base_addr           =>  x"00000000", 
    high_addr           =>  x"00000FFF"
  )
  port map ( 
    rstn_i              =>  poweron_rstn_i, 
    clk_i               =>  clk_i, 
    master_i            =>  axi_slave0_master_w, 
    slave_o             =>  axi_slave0_slave_w
  );

  axi4l_uart_slave_u   : axi4l_uart_slave 
  generic map ( 
    base_addr           =>  x"00000000", 
    high_addr           =>  x"8000001F", 
    fifo_size           =>  3
  )
  port map ( 
    master_i            =>  axi_slave1_master_w, 
    slave_o             =>  axi_slave1_slave_w, 
    rstn_i              =>  poweron_rstn_i, 
    clk_i               =>  clk_i, 
    uart_rx_i           =>  uart_rx_i, 
    uart_tx_o           =>  uart_tx_o, 
    uart_cts_i          =>  uart_cts_i, 
    uart_rts_o          =>  uart_rts_o
  );

  axi4l_wdt_slave_u    : axi4l_wdt_slave 
  generic map ( 
    base_addr           =>  x"80000100", 
    high_addr           =>  x"80000103"
  )
  port map ( 
    master_i            =>  axi_slaves2master_w, 
    slave_o             =>  axi_slave0_master_w, 
    ext_rstn_i          =>  ext_rstn_w, 
    periph_rstn_i       =>  poweron_rstn_i, 
    clk_i               =>  clk_i, 
    wdt_rstn_o          =>  wdt_rstn_w
  );

  axi4l_gpio_slave_u   : axi4l_gpio_slave 
  generic map ( 
    base_addr           =>  13, 
    high_addr           =>  x"80000207", 
    gpio_size           =>  GPIO_SIZE
  )
  port map ( 
    master_i            =>  axi_slave3_master_w, 
    slave_o             =>  axi_slave3_slave_w, 
    rstn_i              =>  poweron_rstn_i, 
    clk_i               =>  clk_i, 
    tri_o               =>  gpio_tri_o, 
    rports_i            =>  gpio_rd_i, 
    wports_o            =>  gpio_wr_o
  );

  compressor_v1_1_u    : compressor_v1_1 
  generic map ( 
    c_s00_axi_data_width  =>  x"80000300", 
    c_s00_axi_addr_width  =>  x"80000303"
  )
  port map ( 
    s00_axi_aclk        =>  clk_i, 
    s00_axi_aresetn     =>  poweron_rstn_i, 
    s00_axi_awaddr      =>  axi_slave4_master_w.awaddr, 
    s00_axi_awprot      =>  axi_slave4_master_w.awprot, 
    s00_axi_awvalid     =>  axi_slave4_master_w.awvalid, 
    s00_axi_awready     =>  axi_slave4_slave_w.awready, 
    s00_axi_wdata       =>  axi_slave4_master_w.wdata, 
    s00_axi_wstrb       =>  axi_slave4_master_w.wstrb, 
    s00_axi_wvalid      =>  axi_slave4_master_w.wvalid, 
    s00_axi_wready      =>  axi_slave4_slave_w.wready, 
    s00_axi_bresp       =>  axi_slave4_slave_w.bresp, 
    s00_axi_bvalid      =>  axi_slave4_slave_w.bvalid, 
    s00_axi_bready      =>  axi_slave4_master_w.bready, 
    s00_axi_araddr      =>  axi_slave4_master_w.araddr, 
    s00_axi_arprot      =>  axi_slave4_master_w.arprot, 
    s00_axi_arvalid     =>  axi_slave4_master_w.arvalid, 
    s00_axi_arready     =>  axi_slave4_slave_w.arready, 
    s00_axi_rdata       =>  axi_slave4_slave_w.rdata, 
    s00_axi_rresp       =>  axi_slave4_slave_w.rresp, 
    s00_axi_rvalid      =>  axi_slave4_slave_w.rvalid, 
    s00_axi_rready      =>  axi_slave4_master_w.rready
  );

  disabled_dmem_g : if not ENABLE_DMEM generate
  begin
    mem0_gnt_w <= '0';
    mem0_err_w <= '1';
    mem0_rdata_w <= x"deadbeef";
    mem_ev_ecc_addr_w <= '0';
  end generate;
  enable_dmem_g : if ENABLE_DMEM and not ENABLE_DMEM_ECC generate
  begin
    unaligned_memory_u   : unaligned_memory 
    generic map ( 
      base_addr           =>  DMEM_BASE_ADDR, 
      high_addr           =>  DMEM_HIGH_ADDR
    )
    port map ( 
     rstn_i              =>  poweron_rstn_i, 
     clk_i               =>  clk_i, 
     s_wr_ready_o        =>  open, 
     s_rd_ready_o        =>  open, 
     s_wr_en_i           =>  mem0_wren_w, 
     s_rd_en_i           =>  mem0_rden_w, 
     s_done_o            =>  mem0_gnt_w, 
     s_error_o           =>  mem0_err_w, 
     s_addr_i            =>  mem0_addr_w, 
     s_wdata_i           =>  mem0_wdata_w, 
     s_wstrb_i           =>  mem0_wstrb_w, 
     s_rdata_o           =>  mem0_rdata_w
    );
    mem_ev_ecc_addr_w  <= '0';
  end generate;
  enable_dmem_g : if ENABLE_DMEM and ENABLE_DMEM_ECC generate
  begin
    unaligned_memory_ecc_u : unaligned_memory 
    generic map ( 
      base_addr           =>  DMEM_BASE_ADDR, 
      high_addr           =>  DMEM_HIGH_ADDR
    )
    port map ( 
     rstn_i              =>  poweron_rstn_i, 
     clk_i               =>  clk_i, 
     s_wr_ready_o        =>  open, 
     s_rd_ready_o        =>  open, 
     s_wr_en_i           =>  mem0_wren_w, 
     s_rd_en_i           =>  mem0_rden_w, 
     s_done_o            =>  mem0_gnt_w, 
     s_error_o           =>  mem0_err_w, 
     s_addr_i            =>  mem0_addr_w, 
     s_wdata_i           =>  mem0_wdata_w, 
     s_wstrb_i           =>  mem0_wstrb_w, 
     s_rdata_o           =>  mem0_rdata_w, 
     ev_rdata_valid_o    =>  mem_ev_rdata_valid_w, 
     ev_sb_error_o       =>  mem_ev_sb_error_w, 
     ev_db_error_o       =>  mem_ev_db_error_w, 
     ev_error_addr_o     =>  mem_ev_error_addr_w, 
     ev_ecc_addr_o       =>  mem_ev_ecc_addr_w, 
     ev_enc_data_o       =>  mem_ev_enc_data_w
    );
  end generate;
end architecture;
