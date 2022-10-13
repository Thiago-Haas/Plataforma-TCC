library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity compressor_top is
  port (
    clk_i   : in std_logic;
    awaddr  : in std_logic_vector(4 downto 0);
    awvalid : in std_logic;
    awprot  : in std_logic_vector(2 downto 0);
    wdata   : in std_logic_vector(31 downto 0);
    wstrb   : in std_logic_vector(3 downto 0);
    wvalid  : in std_logic;
    bready  : in std_logic;
    araddr  : in std_logic_vector(4 downto 0);
    arvalid : in std_logic;
    arprot  : in std_logic_vector(2 downto 0);
    rready  : in std_logic;
    awready : out std_logic;
    wready  : out std_logic;
    bresp   : out std_logic_vector(1 downto 0);
    bvalid  : out std_logic;
    arready : out std_logic;
    rdata   : out std_logic_vector(31 downto 0);
    rresp   : out std_logic_vector(1 downto 0);
    rvalid  : out std_logic
  );
  
architecture arch of compressor_top is
  signal periph_rstn_w : std_logic;

  compressor_v1_1_u    : entity work.compressor_v1_1 
  generic map ( 
    c_s00_axi_data_width  =>  32, 
    c_s00_axi_addr_width  =>  4
  )
  port map ( 
    s00_axi_aclk        =>  clk_i, 
    s00_axi_aresetn     =>  periph_rstn_w, 
    s00_axi_awaddr      =>  awaddr, 
    s00_axi_awprot      =>  awprot, 
    s00_axi_awvalid     =>  awvalid, 
    s00_axi_awready     =>  awready, 
    s00_axi_wdata       =>  wdata, 
    s00_axi_wstrb       =>  wstrb, 
    s00_axi_wvalid      =>  wvalid, 
    s00_axi_wready      =>  wready, 
    s00_axi_bresp       =>  bresp, 
    s00_axi_bvalid      =>  bvalid, 
    s00_axi_bready      =>  bready, 
    s00_axi_araddr      =>  araddr, 
    s00_axi_arprot      =>  arprot, 
    s00_axi_arvalid     =>  arvalid, 
    s00_axi_arready     =>  arready, 
    s00_axi_rdata       =>  rdata, 
    s00_axi_rresp       =>  rresp, 
    s00_axi_rvalid      =>  rvalid, 
    s00_axi_rready      =>  rready
  );

end architecture
