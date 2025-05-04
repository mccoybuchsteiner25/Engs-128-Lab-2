library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_wiz_0_wrapper is
  Port (
    clk_o : out std_logic;
    clk_i  : in  std_logic
  );
end clk_wiz_0_wrapper;

architecture Behavioral of clk_wiz_0_wrapper is

  -- Declare the Verilog module as a component
  component clk_wiz_0
    Port (
      clk_o : out std_logic;
      clk_i  : in  std_logic
    );
  end component;

begin

  -- Instantiate the Verilog Clock Wizard
  u_clk_wiz_0 : clk_wiz_0
    port map (
      clk_o => clk_o,
      clk_i  => clk_i
    );

end Behavioral;
