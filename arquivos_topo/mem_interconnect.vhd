library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_interconnect is
  generic (
    MEM0_BASE_ADDR : std_logic_vector(31 downto 0);
    MEM0_HIGH_ADDR : std_logic_vector(31 downto 0)
  );
  port (
    -- instruction memory interface
    imem_rden_i  : in  std_logic;
    imem_addr_i  : in  std_logic_vector(31 downto 0);
    imem_gnt_o   : out std_logic;
    imem_err_o   : out std_logic;
    imem_rdata_o : out std_logic_vector(31 downto 0);

    -- data memory interface
    dmem_wren_i   : in  std_logic;
    dmem_rden_i   : in  std_logic;
    dmem_gnt_o    : out std_logic;
    dmem_err_o    : out std_logic;
    dmem_addr_i   : in  std_logic_vector(31 downto 0);
    dmem_wdata_i  : in  std_logic_vector(31 downto 0);
    dmem_wstrb_i  : in  std_logic_vector(3 downto 0);
    dmem_rdata_o  : out std_logic_vector(31 downto 0);

    -- mem0 interface
    mem0_wren_o   : out std_logic;
    mem0_rden_o   : out std_logic;
    mem0_gnt_i    : in  std_logic;
    mem0_err_i    : in  std_logic;
    mem0_prot_o   : out std_logic_vector(2 downto 0);
    mem0_addr_o   : out std_logic_vector(31 downto 0);
    mem0_wdata_o  : out std_logic_vector(31 downto 0);
    mem0_wstrb_o  : out std_logic_vector(3 downto 0);
    mem0_rdata_i  : in  std_logic_vector(31 downto 0);

    -- mem1 interface
    mem1_wren_o   : out std_logic;
    mem1_rden_o   : out std_logic;
    mem1_gnt_i    : in  std_logic;
    mem1_err_i    : in  std_logic;
    mem1_prot_o   : out std_logic_vector(2 downto 0);
    mem1_addr_o   : out std_logic_vector(31 downto 0);
    mem1_wdata_o  : out std_logic_vector(31 downto 0);
    mem1_wstrb_o  : out std_logic_vector(3 downto 0);
    mem1_rdata_i  : in  std_logic_vector(31 downto 0)

  );
end entity;

architecture arch of mem_interconnect is
  signal imem_req_w   : std_logic;
  signal dmem_req_w   : std_logic;

  signal mem_wren_w   : std_logic;
  signal mem_rden_w   : std_logic;
  signal mem_gnt_w    : std_logic;
  signal mem_err_w    : std_logic;
  signal mem_addr_w   : std_logic_vector(31 downto 0);
  signal mem_wdata_w  : std_logic_vector(31 downto 0);
  signal mem_wstrb_w  : std_logic_vector(3 downto 0);
  signal mem_rdata_w  : std_logic_vector(31 downto 0);

  signal mem0_req_w : std_logic;
  signal mem1_req_w : std_logic;
begin

  -- access request signals, priority to instruction memory access
  imem_req_w <= imem_rden_i;
  dmem_req_w <= (dmem_wren_i or dmem_rden_i) and not imem_req_w;

  imem_gnt_o   <= mem_gnt_w and imem_req_w;
  imem_err_o   <= mem_err_w and imem_req_w;
  imem_rdata_o <= mem_rdata_w;

  dmem_gnt_o   <= mem_gnt_w and dmem_req_w;
  dmem_err_o   <= mem_err_w and dmem_req_w;
  dmem_rdata_o <= mem_rdata_w;

  -- select input interface
  mem_wren_w  <= '0'         when imem_req_w = '1' else dmem_wren_i;
  mem_rden_w  <= imem_rden_i when imem_req_w = '1' else dmem_rden_i;
  mem_addr_w  <= imem_addr_i when imem_req_w = '1' else dmem_addr_i;
  mem_wdata_w <= dmem_wdata_i; -- only dmem interface writes
  mem_wstrb_w <= "1111"      when imem_req_w = '1' else dmem_wstrb_i;

  -- select memory based on address
  mem0_req_w <= '1' when unsigned(MEM0_BASE_ADDR) <= unsigned(mem_addr_w) and unsigned(mem_addr_w) <= unsigned(MEM0_HIGH_ADDR) else '0';
  mem1_req_w <= not mem0_req_w;

  -- set selected memory signals
  mem0_wren_o    <= mem_wren_w and mem0_req_w;
  mem0_rden_o    <= mem_rden_w and mem0_req_w;
  mem0_prot_o(0) <= '0'; -- unprivileged access
  mem0_prot_o(1) <= '1'; -- non-secure access
  mem0_prot_o(2) <= imem_req_w;
  mem0_addr_o    <= mem_addr_w;
  mem0_wdata_o   <= mem_wdata_w;
  mem0_wstrb_o   <= mem_wstrb_w;

  mem1_wren_o    <= mem_wren_w and mem1_req_w;
  mem1_rden_o    <= mem_rden_w and mem1_req_w;
  mem1_prot_o(0) <= '0'; -- unprivileged access
  mem1_prot_o(1) <= '1'; -- non-secure access
  mem1_prot_o(2) <= imem_req_w;
  mem1_addr_o    <= mem_addr_w;
  mem1_wdata_o   <= mem_wdata_w;
  mem1_wstrb_o   <= mem_wstrb_w;

  -- attribute processor signals based on selected memory
  mem_gnt_w  <= mem0_gnt_i when mem0_req_w = '1' else
                mem1_gnt_i; -- when mem1_req_w = '1'
  mem_err_w  <= mem0_err_i when mem0_req_w = '1' else
                mem1_err_i; -- when mem1_req_w = '1'
  mem_rdata_w <= mem0_rdata_i when mem0_req_w = '1' else
                 mem1_rdata_i; -- when mem1_req_w = '1'

end architecture;
