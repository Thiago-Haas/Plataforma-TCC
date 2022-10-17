library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.axi4l_slave;

entity axi4l_bram is
  generic (
    BASE_ADDR    : std_logic_vector(31 downto 0);
    HIGH_ADDR    : std_logic_vector(31 downto 0);
    ECC          : boolean;
    SIM_INIT_AHX : boolean;
    AHX_FILEPATH : string
  );
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;

    -- AXI interface
    master_i : in  AXI4L_MASTER_TO_SLAVE;
    slave_o  : out AXI4L_SLAVE_TO_MASTER;

    -- events
    ev_rdata_valid_o : out std_logic;
    ev_sb_error_o    : out std_logic;
    ev_db_error_o    : out std_logic;
    ev_error_addr_o  : out std_logic_vector(31 downto 0);
    ev_ecc_addr_o    : out std_logic_vector(31 downto 0);
    ev_enc_data_o    : out std_logic_vector(38 downto 0)

  );
end entity;

architecture arch of axi4l_bram is
  constant SIZE : integer := to_integer(unsigned(HIGH_ADDR)) - to_integer(unsigned(BASE_ADDR)) + 1;

  signal mem_wr_ready_w : std_logic;
  signal mem_rd_ready_w : std_logic;
  signal mem_wr_en_w    : std_logic;
  signal mem_rd_en_w    : std_logic;
  signal mem_done_w     : std_logic;
  signal mem_error_w    : std_logic;
  signal mem_addr_w     : std_logic_vector(31 downto 0);
  signal mem_wdata_w    : std_logic_vector(31 downto 0);
  signal mem_wstrb_w    : std_logic_vector(3 downto 0);
  signal mem_rdata_w    : std_logic_vector(31 downto 0);

begin

  axi4l_slave_u : axi4l_slave
  generic map (
    BASE_ADDR => BASE_ADDR,
    HIGH_ADDR => HIGH_ADDR
  )
  port map (
    clk_i       => clk_i,
    rstn_i      => rstn_i,
    master_i    => master_i,
    slave_o     => slave_o,
    wr_ready_i  => mem_wr_ready_w,
    rd_ready_i  => mem_rd_ready_w,
    done_i      => mem_done_w,
    error_i     => mem_error_w,
    rdata_i     => mem_rdata_w,
    wr_en_o     => mem_wr_en_w,
    rd_en_o     => mem_rd_en_w,
    addr_o      => mem_addr_w,
    prot_o      => open,
    wdata_o     => mem_wdata_w,
    strb_o      => mem_wstrb_w
  );

  ecc_g : if ECC generate
    unaligned_ecc_memory_u : entity work.unaligned_ecc_memory
    generic map (
      BASE_ADDR => x"00000000",
      HIGH_ADDR => std_logic_vector(to_unsigned(SIZE-1, 32)),
      SIM_INIT_AHX => SIM_INIT_AHX,
      AHX_FILEPATH => AHX_FILEPATH
    )
    port map (
      rstn_i        => rstn_i,
      clk_i         => clk_i,
      s_wr_ready_o  => mem_wr_ready_w,
      s_rd_ready_o  => mem_rd_ready_w,
      s_wr_en_i     => mem_wr_en_w,
      s_rd_en_i     => mem_rd_en_w,
      s_done_o      => mem_done_w,
      s_error_o     => mem_error_w,
      s_addr_i      => mem_addr_w,
      s_wdata_i     => mem_wdata_w,
      s_wstrb_i     => mem_wstrb_w,
      s_rdata_o     => mem_rdata_w,
      -- events information
      ev_rdata_valid_o => ev_rdata_valid_o,
      ev_sb_error_o    => ev_sb_error_o,
      ev_db_error_o    => ev_db_error_o,
      ev_error_addr_o  => ev_error_addr_o,
      ev_ecc_addr_o    => ev_ecc_addr_o,
      ev_enc_data_o    => ev_enc_data_o
    );

  else generate
    unaligned_memory_u : entity work.unaligned_memory
    generic map (
      BASE_ADDR    => x"00000000",
      HIGH_ADDR    => std_logic_vector(to_unsigned(SIZE-1, 32)),
      SIM_INIT_AHX => SIM_INIT_AHX,
      AHX_FILEPATH => AHX_FILEPATH
    )
    port map (
      rstn_i       => rstn_i,
      clk_i        => clk_i,
      s_wr_ready_o => mem_wr_ready_w,
      s_rd_ready_o => mem_rd_ready_w,
      s_wr_en_i    => mem_wr_en_w,
      s_rd_en_i    => mem_rd_en_w,
      s_done_o     => mem_done_w,
      s_error_o    => mem_error_w,
      s_addr_i     => mem_addr_w,
      s_wdata_i    => mem_wdata_w,
      s_wstrb_i    => mem_wstrb_w,
      s_rdata_o    => mem_rdata_w
    );
    ev_rdata_valid_o <= '0';
    ev_sb_error_o    <= '0';
    ev_db_error_o    <= '0';
    ev_error_addr_o  <= (others => '0');
    ev_ecc_addr_o    <= (others => '0');
    ev_enc_data_o    <= (others => '0');
  end generate;

end architecture;
