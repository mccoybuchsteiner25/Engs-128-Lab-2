----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/01/2025 12:26:00 PM
-- Design Name: 
-- Module Name: Double_FF_sync_parallel - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity flipflop is   
    generic( AC_DATA_WIDTH : integer := 24);
    Port (
        clk_i : in std_logic;
        async_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        sync_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0)
        );
end flipflop;

architecture Behavioral of flipflop is
    signal reg : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
begin

sync_process : process(clk_i)
begin
    if rising_edge(clk_i) then
        reg <= async_data_i;
        sync_data_o <= reg;
    end if;
 end process;

end Behavioral;
