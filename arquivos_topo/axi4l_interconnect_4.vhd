library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi4l_pkg.all;

entity axi4l_interconnect_4 is
  generic (
    SLAVE0_BASE_ADDR : std_logic_vector(31 downto 0);
    SLAVE0_HIGH_ADDR : std_logic_vector(31 downto 0);
    SLAVE1_BASE_ADDR : std_logic_vector(31 downto 0);
    SLAVE1_HIGH_ADDR : std_logic_vector(31 downto 0);
    SLAVE2_BASE_ADDR : std_logic_vector(31 downto 0);
    SLAVE2_HIGH_ADDR : std_logic_vector(31 downto 0);
    SLAVE3_BASE_ADDR : std_logic_vector(31 downto 0);
    SLAVE3_HIGH_ADDR : std_logic_vector(31 downto 0)
  );
  port (
    rstn_i : in std_logic;
    clk_i  : in std_logic;
    ----------------- MASTER interface ----------------
    master_i : in  AXI4L_MASTER_TO_SLAVE;
    slave_o  : out AXI4L_SLAVE_TO_MASTER;

    ----------------- SLAVE 0 interface ----------------
    master0_o : out AXI4L_MASTER_TO_SLAVE;
    slave0_i  : in  AXI4L_SLAVE_TO_MASTER;

    ----------------- SLAVE 1 interface ----------------
    master1_o : out AXI4L_MASTER_TO_SLAVE;
    slave1_i  : in  AXI4L_SLAVE_TO_MASTER;

    ----------------- SLAVE 2 interface ----------------
    master2_o : out AXI4L_MASTER_TO_SLAVE;
    slave2_i  : in  AXI4L_SLAVE_TO_MASTER;

    ----------------- SLAVE 3 interface ----------------
    master3_o : out AXI4L_MASTER_TO_SLAVE;
    slave3_i  : in  AXI4L_SLAVE_TO_MASTER;

    ----------------- external interface ----------------
    ext_master_o : out AXI4L_MASTER_TO_SLAVE;
    ext_slave_i  : in  AXI4L_SLAVE_TO_MASTER
  );
end entity;

architecture arch of axi4l_interconnect_4 is
  signal slave0_awvalid_w : std_logic;
  signal slave0_arvalid_w : std_logic;
  signal slave0_req_r     : std_logic;
  signal slave1_awvalid_w : std_logic;
  signal slave1_arvalid_w : std_logic;
  signal slave1_req_r     : std_logic;
  signal slave2_awvalid_w : std_logic;
  signal slave2_arvalid_w : std_logic;
  signal slave2_req_r     : std_logic;
  signal slave3_awvalid_w : std_logic;
  signal slave3_arvalid_w : std_logic;
  signal slave3_req_r     : std_logic;
  signal ext_awvalid_w    : std_logic;
  signal ext_arvalid_w    : std_logic;
  signal ext_req_r        : std_logic;

  signal slave_w : AXI4L_SLAVE_TO_MASTER;
begin

  slave0_awvalid_w <= master_i.awvalid when (unsigned(SLAVE0_BASE_ADDR) <= unsigned(master_i.awaddr) and unsigned(master_i.awaddr) <= unsigned(SLAVE0_HIGH_ADDR)) else '0';
  slave0_arvalid_w <= master_i.arvalid when (unsigned(SLAVE0_BASE_ADDR) <= unsigned(master_i.araddr) and unsigned(master_i.araddr) <= unsigned(SLAVE0_HIGH_ADDR)) else '0';

  slave1_awvalid_w <= master_i.awvalid when (unsigned(SLAVE1_BASE_ADDR) <= unsigned(master_i.awaddr) and unsigned(master_i.awaddr) <= unsigned(SLAVE1_HIGH_ADDR)) else '0';
  slave1_arvalid_w <= master_i.arvalid when (unsigned(SLAVE1_BASE_ADDR) <= unsigned(master_i.araddr) and unsigned(master_i.araddr) <= unsigned(SLAVE1_HIGH_ADDR)) else '0';

  slave2_awvalid_w <= master_i.awvalid when (unsigned(SLAVE2_BASE_ADDR) <= unsigned(master_i.awaddr) and unsigned(master_i.awaddr) <= unsigned(SLAVE2_HIGH_ADDR)) else '0';
  slave2_arvalid_w <= master_i.arvalid when (unsigned(SLAVE2_BASE_ADDR) <= unsigned(master_i.araddr) and unsigned(master_i.araddr) <= unsigned(SLAVE2_HIGH_ADDR)) else '0';

  slave3_awvalid_w <= master_i.awvalid when (unsigned(SLAVE3_BASE_ADDR) <= unsigned(master_i.awaddr) and unsigned(master_i.awaddr) <= unsigned(SLAVE3_HIGH_ADDR)) else '0';
  slave3_arvalid_w <= master_i.arvalid when (unsigned(SLAVE3_BASE_ADDR) <= unsigned(master_i.araddr) and unsigned(master_i.araddr) <= unsigned(SLAVE3_HIGH_ADDR)) else '0';

  ext_awvalid_w <= master_i.awvalid and not (slave0_awvalid_w or slave1_awvalid_w or slave2_awvalid_w or slave3_awvalid_w);
  ext_arvalid_w <= master_i.arvalid and not (slave0_arvalid_w or slave1_arvalid_w or slave2_arvalid_w or slave3_arvalid_w);

  grant_req_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      slave0_req_r <= '0';
      slave1_req_r <= '0';
      slave2_req_r <= '0';
      slave3_req_r <= '0';
      ext_req_r    <= '0';
    elsif rising_edge(clk_i) then
      -- grants permission to access to requested slave
      if slave0_awvalid_w = '1' or slave0_arvalid_w = '1' then
        slave0_req_r <= '1';
      elsif slave1_awvalid_w = '1' or slave1_arvalid_w = '1' then
        slave1_req_r <= '1';
      elsif slave2_awvalid_w = '1' or slave2_arvalid_w = '1' then
        slave2_req_r <= '1';
      elsif slave3_awvalid_w = '1' or slave3_arvalid_w = '1' then
        slave3_req_r <= '1';
      elsif ext_awvalid_w = '1' or ext_arvalid_w = '1' then
        ext_req_r <= '1';
      -- clear registers when operation is finished
      elsif (slave_w.rvalid = '1' and master_i.rready = '1') or
            (slave_w.bvalid = '1' and master_i.bready = '1') then
        slave0_req_r <= '0';
        slave1_req_r <= '0';
        slave2_req_r <= '0';
        slave3_req_r <= '0';
        ext_req_r    <= '0';
      end if;
    end if;
  end process;

  slave_w <= slave0_i    when (slave0_awvalid_w or slave0_arvalid_w or slave0_req_r) = '1' else
             slave1_i    when (slave1_awvalid_w or slave1_arvalid_w or slave1_req_r) = '1' else
             slave2_i    when (slave2_awvalid_w or slave2_arvalid_w or slave2_req_r) = '1' else
             slave3_i    when (slave3_awvalid_w or slave3_arvalid_w or slave3_req_r) = '1' else
             ext_slave_i when (ext_awvalid_w    or ext_arvalid_w    or ext_req_r   ) = '1' else
             AXI4L_S2M_DECERR;
  slave_o <= slave_w;

  master0_o <= (
    awaddr  => master_i.awaddr,
    awvalid => slave0_awvalid_w,
    awprot  => master_i.awprot,
    wdata   => master_i.wdata,
    wstrb   => master_i.wstrb,
    wvalid  => master_i.wvalid,
    bready  => master_i.bready,
    araddr  => master_i.araddr,
    arvalid => slave0_arvalid_w,
    arprot  => master_i.arprot,
    rready  => master_i.rready
  );

  master1_o <= (
    awaddr  => master_i.awaddr,
    awvalid => slave1_awvalid_w,
    awprot  => master_i.awprot,
    wdata   => master_i.wdata,
    wstrb   => master_i.wstrb,
    wvalid  => master_i.wvalid,
    bready  => master_i.bready,
    araddr  => master_i.araddr,
    arvalid => slave1_arvalid_w,
    arprot  => master_i.arprot,
    rready  => master_i.rready
  );

  master2_o <= (
    awaddr  => master_i.awaddr,
    awvalid => slave2_awvalid_w,
    awprot  => master_i.awprot,
    wdata   => master_i.wdata,
    wstrb   => master_i.wstrb,
    wvalid  => master_i.wvalid,
    bready  => master_i.bready,
    araddr  => master_i.araddr,
    arvalid => slave2_arvalid_w,
    arprot  => master_i.arprot,
    rready  => master_i.rready
  );

  master3_o <= (
    awaddr  => master_i.awaddr,
    awvalid => slave3_awvalid_w,
    awprot  => master_i.awprot,
    wdata   => master_i.wdata,
    wstrb   => master_i.wstrb,
    wvalid  => master_i.wvalid,
    bready  => master_i.bready,
    araddr  => master_i.araddr,
    arvalid => slave3_arvalid_w,
    arprot  => master_i.arprot,
    rready  => master_i.rready
  );

  ext_master_o <= (
    awaddr  => master_i.awaddr,
    awvalid => ext_awvalid_w,
    awprot  => master_i.awprot,
    wdata   => master_i.wdata,
    wstrb   => master_i.wstrb,
    wvalid  => master_i.wvalid,
    bready  => master_i.bready,
    araddr  => master_i.araddr,
    arvalid => ext_arvalid_w,
    arprot  => master_i.arprot,
    rready  => master_i.rready
  );

end architecture;
