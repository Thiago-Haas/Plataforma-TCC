library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

library work;
use work.axi4l_pkg.all;

entity axi4l_master is
  port (
    ----------------- SYSTEM interface ----------------
    wren_i  : in  std_logic;
    rden_i  : in  std_logic;
    gnt_o   : out std_logic;
    err_o   : out std_logic;
    prot_i  : in  std_logic_vector(2 downto 0);
    addr_i  : in  std_logic_vector(31 downto 0);
    wdata_i : in  std_logic_vector(31 downto 0);
    wstrb_i : in  std_logic_vector(3 downto 0);
    rdata_o : out std_logic_vector(31 downto 0);

    -- sync --
    rstn_i : in std_logic;
    clk_i  : in std_logic;

    -- AXI interface
    slave_i  : in  AXI4L_SLAVE_TO_MASTER;
    master_o : out AXI4L_MASTER_TO_SLAVE;

    -- event
    timeout_o : out std_logic

  );
end entity;

architecture arch of axi4l_master is
  constant IDLE       : std_logic_vector(2 downto 0) := "000";
  constant WR_ADDR    : std_logic_vector(2 downto 0) := "001";
  constant WR_DATA    : std_logic_vector(2 downto 0) := "010";
  constant WR_RESP    : std_logic_vector(2 downto 0) := "011";
  constant RD_ADDR    : std_logic_vector(2 downto 0) := "100";
  constant RD_DATA    : std_logic_vector(2 downto 0) := "101";
  constant GRANT_RESP : std_logic_vector(2 downto 0) := "110";
  constant GRANT_ERR  : std_logic_vector(2 downto 0) := "111";

  signal state_r : std_logic_vector(2 downto 0);
  signal next_w  : std_logic_vector(2 downto 0);

  -- Synplify flags
  attribute syn_preserve : boolean;
  attribute syn_preserve of state_r : signal is true;

  -- read data
  signal rdata_r : std_logic_vector(31 downto 0);
  signal resp_r  : std_logic_vector(1 downto 0);

  constant AMBA_TIMEOUT   : integer := 1023;
  constant TIME_CNT_WIDTH : integer := integer(ceil(log2(real(AMBA_TIMEOUT))));
  signal time_counter_r : std_logic_vector(TIME_CNT_WIDTH-1 downto 0);
  signal timeout_w      : std_logic;

  signal err_w   : std_logic;
begin

  curr_state_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      state_r <= IDLE;
    elsif rising_edge(clk_i) then
      state_r <= next_w;
    end if;
  end process;

  next_state_p : process(all)
  begin
    case state_r is

      when IDLE =>
        if wren_i = '1' then
          next_w <= WR_ADDR;
        elsif rden_i = '1' then
          next_w <= RD_ADDR;
        else
          next_w <= IDLE;
        end if;

      when WR_ADDR =>
        if timeout_w = '1' then
          next_w <= GRANT_RESP;
        elsif slave_i.awready = '1' then
          if slave_i.wready = '1' then
            -- if slave has already written, skip WR_DATA
            next_w <= WR_RESP;
          else
            next_w <= WR_DATA;
          end if;
        else
          next_w <= WR_ADDR;
        end if;

      when WR_DATA =>
        if timeout_w = '1' then
          next_w <= GRANT_RESP;
        elsif slave_i.wready = '1' then
          next_w <= WR_RESP;
        else
          next_w <= WR_DATA;
        end if;

      when WR_RESP =>
        if timeout_w = '1' then
          next_w <= GRANT_RESP;
        elsif slave_i.bvalid = '1' then
          next_w <= GRANT_RESP;
        else
          next_w <= WR_RESP;
        end if;

      when RD_ADDR =>
        if timeout_w = '1' then
          next_w <= GRANT_RESP;
        elsif slave_i.arready = '1' then
          next_w <= RD_DATA;
        else
          next_w <= RD_ADDR;
        end if;

      when RD_DATA =>
        if timeout_w = '1' then
          next_w <= GRANT_RESP;
        elsif slave_i.rvalid = '1' then
          next_w <= GRANT_RESP;
        else
          next_w <= RD_DATA;
        end if;

      when GRANT_RESP =>
        next_w <= IDLE;

      when others =>
        next_w <= IDLE;

    end case;
  end process;

  -- write address channel
  master_o.awaddr  <= addr_i;
  master_o.awvalid <= '1' when state_r = WR_ADDR else '0';

  -- write data channel
  master_o.wdata  <= wdata_i;
  master_o.wstrb  <= wstrb_i;
  master_o.awprot <= prot_i;
  master_o.wvalid <= '1' when state_r = WR_ADDR else
                     '1' when state_r = WR_DATA else
                     '0';

  -- write response channel
  master_o.bready <= '1' when state_r = WR_RESP else '0';

  -- read address channel
  master_o.araddr  <= addr_i;
  master_o.arvalid <= '1' when state_r = RD_ADDR else '0';
  master_o.arprot <= prot_i;

  -- read data channel
  master_o.rready <= '1' when state_r = RD_DATA else '0';

  reg_resp_p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if state_r = WR_RESP and slave_i.bvalid = '1' then
        resp_r <= slave_i.bresp;
      elsif state_r = RD_DATA and slave_i.rvalid = '1' then
        resp_r  <= slave_i.rresp;
        rdata_r <= slave_i.rdata;
      end if;
    end if;
  end process;

  timeout_p : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      time_counter_r <= (others => '0');
    elsif rising_edge(clk_i) then
      if state_r = IDLE then
        time_counter_r <= (others => '0');
      elsif timeout_w = '0' then
        time_counter_r <= std_logic_vector(unsigned(time_counter_r) + 1);
      end if;
    end if;
  end process;
  timeout_w <= '1' when unsigned(time_counter_r) >= to_unsigned(AMBA_TIMEOUT, TIME_CNT_WIDTH) else '0';
  timeout_o <= timeout_w;

  -- pragma translate_off
  process
  begin
    wait until rstn_i = '1' and rising_edge(clk_i) and timeout_w = '1';
    report "AMBA TIMEOUT " & to_hstring(addr_i) & " " & std_logic'image(wren_i) severity WARNING;
  end process;
  -- pragma translate_on

  -- response to processor
  err_w   <= '1' when resp_r = RESPONSE_SLVERR else
             '1' when resp_r = RESPONSE_DECERR else
             '1' when timeout_w = '1'          else
             '0';
  gnt_o   <= '1' when state_r = GRANT_RESP else '0';
  err_o   <= '1' when state_r = GRANT_RESP and err_w = '1' else
             '1' when timeout_w = '1' else
             '0';
  rdata_o <= rdata_r;

end architecture;
