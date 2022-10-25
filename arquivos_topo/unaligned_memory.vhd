library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.memory_pkg.all;

entity unaligned_memory is
  generic (
    BASE_ADDR    : std_logic_vector(31 downto 0);
    HIGH_ADDR    : std_logic_vector(31 downto 0);
    AHX_FILEPATH : string
  );
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;
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
    s_rdata_o    : out std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of unaligned_memory is
  signal m_wr_en_w : std_logic;
  signal m_rd_en_w : std_logic;
  signal m_done_w  : std_logic;
  signal m_error_w : std_logic;
  signal m_addr_w  : std_logic_vector(31 downto 0);
  signal m_wdata_w : std_logic_vector(31 downto 0);
  signal m_rdata_w : std_logic_vector(31 downto 0);
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
    m_wr_ready_i => '1',
    m_rd_ready_i => '1',
    m_wr_en_o    => m_wr_en_w,
    m_rd_en_o    => m_rd_en_w,
    m_done_i     => m_done_w,
    m_error_i    => m_error_w,
    m_addr_o     => m_addr_w,
    m_wdata_o    => m_wdata_w,
    m_rdata_i    => m_rdata_w
  );

  sim_mem_g : if SIM_INIT_AHX generate
    memory_sim_inst : memory_sim
    generic map (
      BASE_ADDR    => BASE_ADDR,
      HIGH_ADDR    => HIGH_ADDR,
      AHX_FILEPATH => AHX_FILEPATH,
      INIT_ECC     => FALSE
    )
    port map (
      rstn_i       => rstn_i,
      clk_i        => clk_i,
      wren_i       => m_wr_en_w,
      rden_i       => m_rd_en_w,
      gnt_o        => m_done_w,
      outofrange_o => m_error_w,
      addr_i       => m_addr_w,
      wdata_i      => m_wdata_w,
      rdata_o      => m_rdata_w
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
      wren_i       => m_wr_en_w,
      rden_i       => m_rd_en_w,
      gnt_o        => m_done_w,
      outofrange_o => m_error_w,
      addr_i       => m_addr_w,
      wdata_i      => m_wdata_w,
      rdata_o      => m_rdata_w
    );
  end generate;

end architecture;
