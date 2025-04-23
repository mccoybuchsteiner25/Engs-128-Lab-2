----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: FIFO buffer with AXI stream valid signal
----------------------------------------------------------------------------
-- Library Declarations
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity fifo is
Generic (
    FIFO_DEPTH : integer := 1024;
    DATA_WIDTH : integer := 32);
Port ( 
    clk_i       : in std_logic;
    reset_i     : in std_logic;
    
    -- Write channel
    wr_en_i     : in std_logic;
    wr_data_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Read channel
    rd_en_i     : in std_logic;
    rd_data_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Status flags
    empty_o         : out std_logic;
    full_o          : out std_logic);   
end fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of fifo is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
type mem_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_buf : mem_type := (others => (others => '0'));

signal read_pointer, write_pointer : integer range 0 to FIFO_DEPTH-1 := 0;
signal data_count : integer range 0 to FIFO_DEPTH-1 := 0;
signal full : std_logic := '0';
signal empty : std_logic := '0';

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Processes and Logic
----------------------------------------------------------------------------

synchronous : process(clk_i)
begin
    if rising_edge(clk_i) then
        
        if reset_i = '1' then
            read_pointer <= 0;
            write_pointer <= 0;
        end if;
        
        if full = '1' then
            write_pointer <= 0;
        end if;
        
        if empty = '1' then
            read_pointer <= 0;
        end if;
        
        if wr_en_i = '1' AND full = '0' then
            write_pointer <= write_pointer + 1;
            data_count <= data_count + 1;
        end if;
    
        if rd_en_i = '1' AND empty = '0' then
            read_pointer <= read_pointer + 1;
            data_count <= data_count - 1;
        end if;
        
        if wr_en_i = '1' AND full = '0' then
            fifo_buf(write_pointer) <= wr_data_i;
        end if;
        
        if rd_en_i = '1' AND empty = '0' then
            rd_data_o <= fifo_buf(read_pointer);
        end if;
    
    end if;
end process synchronous;

asynchronous : process
begin
    empty_o <= empty;
    full_o <= full;
    
    if data_count = FIFO_DEPTH then
        full <= '1';
    end if;
    
    if data_count = 0 then
        empty <= '1';
    end if;
    
end process asynchronous;

--write_data : process(clk_i)
--begin
--    if rising_edge(clk_i) then
--        if wr_en_i = '1' AND data_count < FIFO_DEPTH then
--            fifo_buf(write_pointer-1) <= wr_data_i;
--        end if;
--    end if;
--end process write_data;

--read_data : process(clk_i)
--begin
--    if rising_edge(clk_i) then
--        if rd_en_i = '1' AND data_count > 0 then
--            rd_data_o <= fifo_buf(read_pointer-1);
--        end if;
--    end if;
--end process read_data;
        
--write_counter : process(clk_i, wr_en_i)
--begin
--    if rising_edge(clk_i) then
--        if reset_i = '1' OR write_pointer = FIFO_DEPTH then
--            write_pointer <= 1;
--        elsif wr_en_i = '1' and data_count < FIFO_DEPTH then
--            write_pointer <= write_pointer + 1;
--        end if;
--    end if;
--end process write_counter;

--read_counter : process(clk_i, rd_en_i)
--begin
--    if rising_edge(clk_i) then
--        if reset_i = '1' OR read_pointer = FIFO_DEPTH then
--            read_pointer <= 1;
--        elsif rd_en_i = '1' AND data_count > 0 then
--            read_pointer <= read_pointer + 1;
--        end if;
--    end if;
--end process read_counter;

--data_counter : process(clk_i, wr_en_i, rd_en_i)
--begin
--    if rising_edge(clk_i) then
--        empty_o <= '0';
--        full_o <= '0';
--        if reset_i = '0' then
--            if wr_en_i = '1' and data_count < FIFO_DEPTH then 
--                data_count <= data_count + 1;
--            end if;
        
--            if rd_en_i = '1' and data_count > 0 then
--                data_count <= data_count - 1;
--            end if;
            
--            if data_count = FIFO_DEPTH then
--                full_o <= '1';
--            elsif data_count = 0 then
--                empty_o <= '1';
--            end if;
--        else
--            data_count <= 0;
--            empty_o <= '1';
--        end if;
--    end if;
--end process data_counter;

end Behavioral;
