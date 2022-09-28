library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_controller is
  port (
    clk_i : in  std_logic;
    -- reset inputs
    poweron_rstn_i   : in  std_logic;
    btn_rstn_i       : in  std_logic;
    wdt_rstn_i       : in  std_logic;
    periph_timeout_i : in std_logic;
    -- reset outputs
    ext_rstn_o        : out std_logic;
    proc_rstn_o       : out std_logic;
    periph_rstn_o     : out std_logic;
    ext_periph_rstn_o : out std_logic
  );
end entity;

architecture arch of reset_controller is
  signal periph_timeout_rstn_r : std_logic_vector(2 downto 0);
  signal periph_timeout_rstn_w : std_logic;
  -- Synplify attributes to prevent optimization
  attribute syn_preserve : boolean;
  attribute syn_preserve of periph_timeout_rstn_r : signal is TRUE;
begin

  ext_rstn_o <= '0' when poweron_rstn_i = '0' else
                '0' when btn_rstn_i     = '0' else
                '1';

  proc_rstn_o <= '0' when poweron_rstn_i = '0' else
                 '0' when btn_rstn_i     = '0' else
                 '0' when wdt_rstn_i     = '0' else
                 '1';

  periph_timeout_rstn_p : process (poweron_rstn_i, btn_rstn_i, wdt_rstn_i, clk_i)
  begin
    if poweron_rstn_i = '0' or btn_rstn_i = '0' or wdt_rstn_i = '0' then
      -- reset disable
      periph_timeout_rstn_r <= "111";
    elsif rising_edge(clk_i) then
      -- if it is resetting, disable reset
      if periph_timeout_rstn_w = '0' then
        periph_timeout_rstn_r <= "111";
      -- if timeout was identified, enable reset
      elsif periph_timeout_i = '1' then
        periph_timeout_rstn_r <= "000";
      end if;
    end if;
  end process;
  periph_timeout_rstn_w <= (periph_timeout_rstn_r(0) and periph_timeout_rstn_r(1)) or (periph_timeout_rstn_r(0) and periph_timeout_rstn_r(2)) or (periph_timeout_rstn_r(1) and periph_timeout_rstn_r(2));
                 
  periph_rstn_o <= '0' when poweron_rstn_i        = '0' else
                   '0' when btn_rstn_i            = '0' else
                   '0' when wdt_rstn_i            = '0' else
                   '0' when periph_timeout_rstn_w = '0' else
                   '1';

  ext_periph_rstn_o <= '0' when poweron_rstn_i        = '0' else
                       '0' when btn_rstn_i            = '0' else
                       '0' when wdt_rstn_i            = '0' else
                       '0' when periph_timeout_rstn_w = '0' else
                       '1';

end architecture;
