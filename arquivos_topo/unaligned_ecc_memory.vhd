library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.memory_pkg.all;

entity unaligned_ecc_memory is
  generic (
    BASE_ADDR    : std_logic_vector(31 downto 0);
    HIGH_ADDR    : std_logic_vector(31 downto 0);
    AHX_FILEPATH : string
  );
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;

    correct_error_i : in std_logic;

    -- memory interface
    s_wr_ready_o : out std_logic;
    s_rd_ready_o : out std_logic;
    s_wr_en_i    : in  std_logic;
    s_rd_en_i    : in  std_logic;
    s_done_o     : out std_logic;
    s_error_o    : out std_logic;
    s_addr_i     : in  std_logic_vector(31 downto 0);
    s_wdata_i    : in  std_logic_vector(31 downto 0);
    s_wstrb_i    : in  std_logic_vector(3 downto 0);
    s_rdata_o    : out std_logic_vector(31 downto 0);

    -- events
    ev_rdata_valid_o : out std_logic;
    ev_sb_error_o    : out std_logic;
    ev_db_error_o    : out std_logic;
    ev_error_addr_o  : out std_logic_vector(31 downto 0);
    ev_ecc_addr_o    : out std_logic_vector(31 downto 0);
    ev_enc_data_o    : out std_logic_vector(38 downto 0)

  );
end entity;

architecture arch of unaligned_ecc_memory is

  signal m0_wr_ready_w : std_logic;
  signal m0_rd_ready_w : std_logic;
  signal m0_wr_en_w    : std_logic;
  signal m0_rd_en_w    : std_logic;
  signal m0_done_w     : std_logic;
  signal m0_error_w    : std_logic;
  signal m0_addr_w     : std_logic_vector(31 downto 0);
  signal m0_wdata_w    : std_logic_vector(31 downto 0);
  signal m0_rdata_w    : std_logic_vector(31 downto 0);

  signal m1_wr_en_w : std_logic;
  signal m1_rd_en_w : std_logic;
  signal m1_done_w  : std_logic;
  signal m1_error_w : std_logic;
  signal m1_addr_w  : std_logic_vector(31 downto 0);
  signal m1_wdata_w : std_logic_vector(31 downto 0);
  signal m1_rdata_w : std_logic_vector(31 downto 0);

begin

  mem_unaligned_adapter_u : entity work.mem_unaligned_adapter
  port map (
    rstn_i       => rstn_i,
    clk_i        => clk_i,
    -- slave interface
    s_wr_ready_o => s_wr_ready_o,
    s_rd_ready_o => s_rd_ready_o,
    s_wr_en_i    => s_wr_en_i,
    s_rd_en_i    => s_rd_en_i,
    s_done_o     => s_done_o,
    s_error_o    => s_error_o,
    s_addr_i     => s_addr_i,
    s_wdata_i    => s_wdata_i,
    s_wstrb_i    => s_wstrb_i,
    s_rdata_o    => s_rdata_o,
    -- master interface
    m_wr_ready_i => m0_wr_ready_w,
    m_rd_ready_i => m0_rd_ready_w,
    m_wr_en_o    => m0_wr_en_w,
    m_rd_en_o    => m0_rd_en_w,
    m_done_i     => m0_done_w,
    m_error_i    => m0_error_w,
    m_addr_o     => m0_addr_w,
    m_wdata_o    => m0_wdata_w,
    m_rdata_i    => m0_rdata_w
  );

  mem_ecc_adapter_u : entity work.mem_ecc_adapter
  generic map (
    BASE_ADDR => BASE_ADDR,
    HIGH_ADDR => HIGH_ADDR
  )
  port map (
    rstn_i => rstn_i,
    clk_i  => clk_i,
    correct_error_i => correct_error_i,
    -- slave
    s_wr_ready_o  => m0_wr_ready_w,
    s_rd_ready_o  => m0_rd_ready_w,
    s_wr_en_i     => m0_wr_en_w,
    s_rd_en_i     => m0_rd_en_w,
    s_done_o      => m0_done_w,
    s_error_o     => m0_error_w,
    s_addr_i      => m0_addr_w,
    s_wdata_i     => m0_wdata_w,
    s_rdata_o     => m0_rdata_w,
    -- master
    m_wr_ready_i  => '1',
    m_rd_ready_i  => '1',
    m_wr_en_o     => m1_wr_en_w,
    m_rd_en_o     => m1_rd_en_w,
    m_done_i      => m1_done_w,
    m_error_i     => m1_error_w,
    m_addr_o      => m1_addr_w,
    m_wdata_o     => m1_wdata_w,
    m_rdata_i     => m1_rdata_w,
    -- event information
    ev_rdata_valid_o => ev_rdata_valid_o,
    ev_sb_error_o    => ev_sb_error_o,
    ev_db_error_o    => ev_db_error_o,
    ev_error_addr_o  => ev_error_addr_o,
    ev_ecc_addr_o    => ev_ecc_addr_o,
    ev_enc_data_o    => ev_enc_data_o
  );

  sim_mem_g : if SIM_INIT_AHX generate
    memory_sim_inst : memory_sim
    generic map (
      BASE_ADDR    => BASE_ADDR,
      HIGH_ADDR    => HIGH_ADDR,
      AHX_FILEPATH => AHX_FILEPATH,
      INIT_ECC     => TRUE
    )
    port map (
      rstn_i       => rstn_i,
      clk_i        => clk_i,
      wren_i       => m1_wr_en_w,
      rden_i       => m1_rd_en_w,
      gnt_o        => m1_done_w,
      outofrange_o => m1_error_w,
      addr_i       => m1_addr_w,
      wdata_i      => m1_wdata_w,
      rdata_o      => m1_rdata_w
    );
  end generate;
  mem_g : if not SIM_INIT_AHX generate
    memory_u : memory
    generic map (
      BASE_ADDR => BASE_ADDR,
      HIGH_ADDR => HIGH_ADDR
    )
    port map (
      rstn_i       => rstn_i,
      clk_i        => clk_i,
      wren_i       => m1_wr_en_w,
      rden_i       => m1_rd_en_w,
      gnt_o        => m1_done_w,
      outofrange_o => m1_error_w,
      addr_i       => m1_addr_w,
      wdata_i      => m1_wdata_w,
      rdata_o      => m1_rdata_w
    );
  end generate;
end architecture;
