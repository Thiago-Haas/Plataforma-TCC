library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.axi4l_pkg.all;
use work.axi4l_slaves_pkg.axi4l_slave;

entity axi4l_wdt_slave is
  generic (
    BASE_ADDR   : std_logic_vector(31 downto 0);
    HIGH_ADDR   : std_logic_vector(31 downto 0)
  );
  port (

    -- AXI interface
    master_i : in  AXI4L_MASTER_TO_SLAVE;
    slave_o  : out AXI4L_SLAVE_TO_MASTER;

    -- sync
    ext_rstn_i    : in std_logic;
    periph_rstn_i : in std_logic;
    clk_i         : in std_logic;

    ----------------- RESET interface ----------------
    wdt_rstn_o : out std_logic

  );
end entity;

architecture arch of axi4l_wdt_slave is
  signal axislv_wr_en_w : std_logic;
  signal axislv_addr_w  : std_logic_vector(31 downto 0);
  signal axislv_wdata_w : std_logic_vector(31 downto 0);
  signal axislv_strb_w  : std_logic_vector(3 downto 0);

  signal timer_r : std_logic_vector(31 downto 0);
  signal rstn_r  : std_logic_vector(2 downto 0);

  signal corr_rstn_w : std_logic;

  -- Synplify flags
  attribute syn_preserve : boolean;
  attribute syn_preserve of rstn_r : signal is true;
begin

  axi4l_slave_u : axi4l_slave
  generic map (
    BASE_ADDR => BASE_ADDR,
    HIGH_ADDR => HIGH_ADDR
  )
  port map (
    clk_i       => clk_i,
    rstn_i      => periph_rstn_i,
    master_i    => master_i,
    slave_o     => slave_o,
    wr_ready_i  => '1',
    rd_ready_i  => '1',
    done_i      => '1',
    error_i     => '0',
    rdata_i     => timer_r,
    wr_en_o     => axislv_wr_en_w,
    rd_en_o     => open,
    addr_o      => axislv_addr_w,
    prot_o      => open,
    wdata_o     => axislv_wdata_w,
    strb_o      => axislv_strb_w
  );

  timer_p : process(ext_rstn_i, clk_i)
  begin
    if ext_rstn_i = '0' then
      timer_r <= x"1DCD6500"; -- set for 10 secs (50MHz)
    elsif rising_edge(clk_i) then
      -- write to timer (feed)
      if axislv_wr_en_w = '1' then
        -- write based on strobe AXI parameter
        if axislv_strb_w(3) = '1' then
          timer_r(31 downto 24) <= axislv_wdata_w(31 downto 24);
        end if;
        if axislv_strb_w(2) = '1' then
          timer_r(23 downto 16) <= axislv_wdata_w(23 downto 16);
        end if;
        if axislv_strb_w(1) = '1' then
          timer_r(15 downto 8)  <= axislv_wdata_w(15 downto 8);
        end if;
        if axislv_strb_w(0) = '1' then
          timer_r(7 downto 0)   <= axislv_wdata_w(7 downto 0);
        end if;
      else -- decrement timer
        timer_r <= std_logic_vector(unsigned(timer_r)-1);
      end if;
    end if;
  end process;

  rstn_p : process(ext_rstn_i, clk_i)
  begin
    if ext_rstn_i = '0' then
      rstn_r <= "111"; -- deactivate wdt reset
    elsif rising_edge(clk_i) then
      if timer_r = x"00000000" then -- if timer went to 0
        rstn_r <= "000"; -- activate wdt reset
      else
        rstn_r <= "111"; -- deactivate wdt reset
      end if;
    end if;
  end process;
  -- votes the most common value
  corr_rstn_w <= (rstn_r(0) and rstn_r(1)) or (rstn_r(0) and rstn_r(2)) or (rstn_r(1) and rstn_r(2));
  wdt_rstn_o <= corr_rstn_w;

end architecture;
