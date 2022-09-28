library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.axi4l_slave;

entity axi4l_gpio_slave is
  generic (
    BASE_ADDR : std_logic_vector(31 downto 0);
    HIGH_ADDR : std_logic_vector(31 downto 0);
    GPIO_SIZE : integer
  );
  port (
    -- AXI interface
    master_i : in  AXI4L_MASTER_TO_SLAVE;
    slave_o  : out AXI4L_SLAVE_TO_MASTER;

    -- sync
    rstn_i : in std_logic;
    clk_i  : in std_logic;

    -- GPIO tristate and output and input values
    tri_o    : out std_logic_vector(GPIO_SIZE-1 downto 0);
    rports_i : in  std_logic_vector(GPIO_SIZE-1 downto 0);
    wports_o : out std_logic_vector(GPIO_SIZE-1 downto 0)
  );
end entity;

architecture arch of axi4l_gpio_slave is
  -- AXI addresses
  constant TRISTATE_CONFIGURATION_ADDR : std_logic_vector(31 downto 0) := x"00000000";
  constant GPIO_ADDR                   : std_logic_vector(31 downto 0) := x"00000004";
  --
  signal axislv_wr_en_w : std_logic;
  signal axislv_addr_w  : std_logic_vector(31 downto 0);
  signal axislv_rdata_w : std_logic_vector(31 downto 0);
  signal axislv_wdata_w : std_logic_vector(31 downto 0);
  -- tri-state configuration register
  -- 1: input (high impedance)
  -- 0: ouput
  signal tristate_configuration_r : std_logic_vector(GPIO_SIZE-1 downto 0);
  -- signals to the output
  signal wports_r : std_logic_vector(GPIO_SIZE-1 downto 0);
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
    wr_ready_i  => '1',
    rd_ready_i  => '1',
    done_i      => '1',
    error_i     => '0',
    rdata_i     => axislv_rdata_w,
    wr_en_o     => axislv_wr_en_w,
    rd_en_o     => open,
    addr_o      => axislv_addr_w,
    prot_o      => open,
    wdata_o     => axislv_wdata_w,
    strb_o      => open
  );

  axislv_rdata_w <= (31 downto GPIO_SIZE => '0') & tristate_configuration_r
                        when axislv_addr_w = TRISTATE_CONFIGURATION_ADDR else
                    (31 downto GPIO_SIZE => '0') & rports_i
                        when axislv_addr_w = GPIO_ADDR else
                    x"deadbeef";

  gpio_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      tristate_configuration_r <= (others => '1'); -- defaults to input (high impedance)
    elsif rising_edge(clk_i) then
      if axislv_wr_en_w = '1' then
        if axislv_addr_w = TRISTATE_CONFIGURATION_ADDR then
          tristate_configuration_r <= axislv_wdata_w(GPIO_SIZE-1 downto 0);
        elsif axislv_addr_w = GPIO_ADDR then
          wports_r <= axislv_wdata_w(GPIO_SIZE-1 downto 0);
        end if;
      end if;
    end if;
  end process;

  tri_o    <= tristate_configuration_r;
  wports_o <= wports_r;

end architecture;
