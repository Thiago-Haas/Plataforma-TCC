library ieee;
use ieee.std_logic_1164.all;

library work;
use work.axi4l_pkg.all;

entity zed_top is
  port (
    btn_rst_i : in std_logic;
    clk_i     : in std_logic;

    -- UART
    uart_rx_i  : in  std_logic;
    uart_tx_o  : out std_logic;
    uart_cts_i : in  std_logic;
    uart_rts_o : out std_logic;

    -- GPIO
    user_btn_i : in    std_logic;
    leds_o     : out   std_logic_vector(7 downto 0);
    pmod_io    : inout std_logic_vector(3 downto 0)

  );
end zed_top;

architecture arch of zed_top is
  signal rstn_w        : std_logic;
  signal clk50_w       : std_logic;
  signal locked_w      : std_logic;
  signal periph_rstn_w : std_logic;

  signal gpio_tri_w : std_logic_vector(12 downto 0);
  signal gpio_rd_w  : std_logic_vector(12 downto 0);
  signal gpio_wr_w  : std_logic_vector(12 downto 0);

  signal axi4l_master_w  : AXI4L_MASTER_TO_SLAVE;
  signal axi4l_slave_w   : AXI4L_SLAVE_TO_MASTER;
  signal axi4l_master0_w : AXI4L_MASTER_TO_SLAVE;
  signal axi4l_slave0_w  : AXI4L_SLAVE_TO_MASTER;
  
  signal bram_master_w          :  AXI4L_MASTER_TO_SLAVE;
  signal bram_slave_w           :  AXI4L_MASTER_TO_SLAVE;
  signal bram_ev_rdata_valid_w  :  std_logic;
  signal bram_ev_sb_error_w     :  std_logic;
  signal bram_ev_db_error_w     :  std_logic;
  signal bram_ev_error_addr_w   :  std_logic_vector(31 downto 0);
  signal bram_ev_ecc_addr_w     :  std_logic_vector(31 downto 0);
  signal bram_ev_enc_data_w     :  std_logic_vector(38 downto 0);
  
begin

  clk_wiz_u : entity work.clk_wiz_0
  port map (
    clk_in1  => clk_i,
    clk_out1 => clk50_w,
    locked   => locked_w
  );

  rstn_w <= locked_w and not btn_rst_i;

  harv_soc_u : entity work.harv_soc
  generic map (
    PROGRAM_START_ADDR => x"00000000",
    HARV_TMR           => FALSE,
    HARV_ECC           => FALSE,
    ENABLE_ROM         => TRUE,
    ENABLE_DMEM        => TRUE,
    DMEM_BASE_ADDR     => x"08000000",
    DMEM_HIGH_ADDR     => x"08000FFF",
    GPIO_SIZE          => 13
  )
  port map (
    poweron_rstn_i => rstn_w,
    btn_rstn_i     => '1',
    clk_i          => clk50_w,
    start_i        => rstn_w,
    periph_rstn_o  => periph_rstn_w,
    uart_rx_i      => uart_rx_i,
    uart_tx_o      => uart_tx_o,
    uart_cts_i     => uart_cts_i,
    uart_rts_o     => uart_rts_o,
    gpio_tri_o     => gpio_tri_w,
    gpio_rd_i      => gpio_rd_w,
    gpio_wr_o      => gpio_wr_w,
    axi4l_master_o => axi4l_master_w,
    axi4l_slave_i  => axi4l_slave_w,
    ext_event_i    => '0'
  );

  -- fixed in or out pins
  gpio_rd_w(0) <= user_btn_i;
  leds_o <= gpio_wr_w(8 downto 1);
  gpio_rd_w(8 downto 1) <= gpio_wr_w(8 downto 1);
  -- configurable pins
  pmod_io(3) <= 'Z' when gpio_tri_w(12) = '1' else gpio_wr_w(12);
  pmod_io(2) <= 'Z' when gpio_tri_w(11) = '1' else gpio_wr_w(11);
  pmod_io(1) <= 'Z' when gpio_tri_w(10) = '1' else gpio_wr_w(10);
  pmod_io(0) <= 'Z' when gpio_tri_w( 9) = '1' else gpio_wr_w(9);
  gpio_rd_w(12) <= pmod_io(3);
  gpio_rd_w(11) <= pmod_io(2);
  gpio_rd_w(10) <= pmod_io(1);
  gpio_rd_w( 9) <= pmod_io(0);

  axi4l_interconnect_1_u : entity work.axi4l_interconnect_1
  generic map (
    SLAVE0_BASE_ADDR => x"70000000",
    SLAVE0_HIGH_ADDR => x"70007FFF"
  )
  port map (
    rstn_i       => periph_rstn_w,
    clk_i        => clk50_w,
    master_i     => axi4l_master_w,
    slave_o      => axi4l_slave_w,
    master0_o    => axi4l_master0_w,
    slave0_i     => axi4l_slave0_w,
    ext_master_o => open,
    ext_slave_i  => AXI4L_S2M_DECERR
  );

  axi4l_bram_u : entity work.axi4l_bram
  generic map (
    BASE_ADDR 	 => x"70000000",
    HIGH_ADDR 	 => x"70007FFF",
    ECC 	 => FALSE,
    SIM_INIT_AHX => TRUE,
    AHX_FILEPATH => "../../../../../src/helloworld/out/app-sim.ahx"
  )
  port map (
    rstn_i   		=> periph_rstn_w,
    clk_i    		=> clk50_w,
    master_i 		=> bram_master_w,
    slave_o  		=> bram_slave_w
    ev_rdata_valid_o    => bram_ev_rdata_valid_w, 
    ev_sb_error_o       => bram_ev_sb_error_w, 
    ev_db_error_o       => bram_ev_db_error_w, 
    ev_error_addr_o     => bram_ev_error_addr_w, 
    ev_ecc_addr_o       => bram_ev_ecc_addr_w, 
    ev_enc_data_o       => bram_ev_enc_data_w
  );

end arch;
