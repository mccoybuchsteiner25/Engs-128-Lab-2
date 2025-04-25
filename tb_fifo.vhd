----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for AXI Stream FIFO 
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity tb_fifo is
end tb_fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture testbench of tb_fifo is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Constants
constant CLOCK_PERIOD : time := 8ns;        -- 125 MHz clock
constant DATA_WIDTH : integer := 8;         -- FIFO data width
constant FIFO_DEPTH : integer := 10;        -- FIFO depth

----------------------------------------------------------------------------
-- FIFO pointers and signals  
signal fifo_rd_en, fifo_wr_en : std_logic;
signal full, empty : std_logic;
signal reset, clk : std_logic;
signal data_in, data_out : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------  
component fifo is
    Generic (
        FIFO_DEPTH : integer := FIFO_DEPTH;
        DATA_WIDTH : integer := DATA_WIDTH);
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
end component;

----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------   
-- FIFO instance
axi_stream_fifo : fifo
    port map ( 
        clk_i => clk,
        reset_i => reset,
        wr_en_i => fifo_wr_en,
        wr_data_i => data_in,
        rd_en_i => fifo_rd_en,
        rd_data_o => data_out,
        empty_o => empty,
        full_o => full);

----------------------------------------------------------------------------   
-- Clock Generation Processes
----------------------------------------------------------------------------  
clock_gen_process : process
begin
	clk <= '0';				    -- start low
	wait for CLOCK_PERIOD/2;
	loop						-- toggle, wait half a clock period, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;



----------------------------------------------------------------------------   
-- Generate Input Data
----------------------------------------------------------------------------   
generate_fifo_data : process
begin
    -- Initialize
    data_in <= (others => '0');
    wait until rising_edge(clk);
    loop
        if (fifo_wr_en = '1') then
            data_in <= std_logic_vector(unsigned(data_in)+1);
        end if;
        wait for CLOCK_PERIOD;
    end loop;
end process generate_fifo_data;


----------------------------------------------------------------------------   
-- Stim process
----------------------------------------------------------------------------  
stim_proc : process
begin

    -- Initialize
    fifo_rd_en <= '0';
    fifo_wr_en <= '0'; 
    
    -- Asynchronous reset
    reset <= '1';
    wait for 55 ns;
    reset <= '0';
    
    ----------------------------------------------------------------------------   
    -- Write FIFO -- check if FULL flag works as expected
    ----------------------------------------------------------------------------  
    wait until rising_edge(clk);
    fifo_wr_en <= '1'; 
    wait for CLOCK_PERIOD*20;
    fifo_wr_en <= '0';

    ----------------------------------------------------------------------------   
    -- Read FIFO -- check if EMPTY flag works as expected
    ----------------------------------------------------------------------------  
    wait until rising_edge(clk);
    fifo_rd_en <= '1'; 
    wait for CLOCK_PERIOD*20;
    fifo_rd_en <= '0';
    
    ----------------------------------------------------------------------------   
    -- Simultaneous read/write
    ----------------------------------------------------------------------------  
    wait until rising_edge(clk);
    fifo_wr_en <= '1'; 
    wait until rising_edge(clk);
    fifo_rd_en <= '1'; 
    wait for CLOCK_PERIOD*20;
    fifo_rd_en <= '0'; 
    fifo_wr_en <= '0';
    
    
    wait for CLOCK_PERIOD*20;
    std.env.stop;

end process;
----------------------------------------------------------------------------

end testbench;