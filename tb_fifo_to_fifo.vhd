----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for FIFO --> FIFO AXI stream passthrough
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity tb_fifo_to_fifo is
end tb_fifo_to_fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture testbench of tb_fifo_to_fifo is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Constants
constant AXI_DATA_WIDTH : integer := 32;        -- 32-bit AXI data bus
constant AXI_FIFO_DEPTH : integer := 12;        -- AXI stream FIFO depth
constant CLOCK_PERIOD : time := 8ns;            -- 125 MHz clock

-- Signal declarations
signal clk : std_logic := '0';
signal axi_reset_n : std_logic := '1';
signal enable_stream : std_logic := '0';
signal test_num : integer := 0;

----------------------------------------------------------------------------
signal spi_axis_ready : std_logic := '0';

----------------------------------------------------------------------------
-- AXI Stream FIFO
signal fifo_0_axis_data_out, fifo_0_axis_data_in : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal fifo_0_axis_data_out_valid, fifo_0_axis_data_in_valid : std_logic := '0';
signal fifo_0_axis_data_out_last, fifo_0_axis_data_in_last : std_logic := '0';
signal fifo_0_axis_ready : std_logic := '0';

signal fifo_1_axis_data_out : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal fifo_1_axis_data_out_valid : std_logic := '0';
signal fifo_1_axis_data_out_last : std_logic := '0';
signal fifo_1_axis_ready : std_logic := '0';

signal fifo_0_axis_tstrb, fifo_1_axis_tstrb, axis_tstrb : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- AXI Stream FIFO
component axis_fifo is
	generic (
		DATA_WIDTH	: integer	:= AXI_DATA_WIDTH;
		FIFO_DEPTH	: integer	:= AXI_FIFO_DEPTH
	);
	port (
	
		-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;

		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic
	);
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
 -- AXI Stream FIFO (ADC --> FIFO)
fifo_0_adc_to_fifo: axis_fifo
port map (
  
    s00_axis_aclk => clk,
    s00_axis_aresetn => axi_reset_n,    -- button 0
    s00_axis_tready => fifo_0_axis_ready,
    s00_axis_tdata => fifo_0_axis_data_in,
    s00_axis_tstrb => axis_tstrb,
    s00_axis_tlast => fifo_0_axis_data_in_last,     -- not using TLAST
    s00_axis_tvalid => fifo_0_axis_data_in_valid, 

    m00_axis_aclk => clk,
    m00_axis_aresetn => axi_reset_n,
    m00_axis_tvalid => fifo_0_axis_data_out_valid,
    m00_axis_tdata => fifo_0_axis_data_out,
    m00_axis_tstrb => fifo_0_axis_tstrb,             -- not using TSTRB 
    m00_axis_tlast => fifo_0_axis_data_out_last,
    m00_axis_tready => fifo_1_axis_ready);
----------------------------------------------------------------------------
fifo_0_axis_data_in_last <= '0';    -- all data is part of the same stream
axis_tstrb <= (others => '1');      -- all bytes contain valid data
----------------------------------------------------------------------------    
 -- AXI Stream FIFO (FIFO --> SPI)
fifo_1_fifo_to_spi: axis_fifo
port map (
  
    s00_axis_aclk => clk,
    s00_axis_aresetn => axi_reset_n,    -- button 0
    s00_axis_tready => fifo_1_axis_ready,
    s00_axis_tdata => fifo_0_axis_data_out,
    s00_axis_tstrb => fifo_0_axis_tstrb,
    s00_axis_tlast => fifo_0_axis_data_out_last,   -- not using TLAST
    s00_axis_tvalid => fifo_0_axis_data_out_valid, 

    m00_axis_aclk => clk,
    m00_axis_aresetn => axi_reset_n,
    m00_axis_tvalid => fifo_1_axis_data_out_valid,
    m00_axis_tdata => fifo_1_axis_data_out,
    m00_axis_tstrb => fifo_1_axis_tstrb,             -- not using TSTRB 
    m00_axis_tlast => fifo_1_axis_data_out_last,
    m00_axis_tready => spi_axis_ready);


----------------------------------------------------------------------------------
-- Initiate process which simulates a master controller wanting to write to AXI stream.
--      This process is blocked on a "Send Flag" (enable_stream).
--      When the flag goes to 1, the process exits the wait state and
--          execute a write transaction.
send_stream : process(axi_reset_n, clk)
begin
    
    if axi_reset_n = '0' then               -- asynchronous reset
        fifo_0_axis_data_in <= x"ABCDEF01";    -- start at some value
    elsif rising_edge(clk) then
        
        if enable_stream = '1' then
            fifo_0_axis_data_in_valid <= '1';
            if fifo_0_axis_ready = '1' then  -- send test data, increment value by one
                fifo_0_axis_data_in <= std_logic_vector(unsigned(fifo_0_axis_data_in) + 1);
            end if;
        else
            fifo_0_axis_data_in_valid <= '0';
        end if;  
    
    end if;
    
end process send_stream;
----------------------------------------------------------------------------   
-- Clock Generation Processes
----------------------------------------------------------------------------  

-- Generate 100 MHz ADC clock      
adc_clock_gen_process : process
begin
	clk <= '0';				-- start low
	wait for CLOCK_PERIOD;	    -- wait for one CLOCK_PERIOD
	
	loop							-- toggle, wait half a clock period, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process adc_clock_gen_process;



----------------------------------------------------------------------------   
-- Stimulus
----------------------------------------------------------------------------  
stim_proc : process
begin
-- Initialize
enable_stream <= '0';   -- Disable data into FIFO 0 S_AXIS interface (testbench to DUT) 
spi_axis_ready <= '0';  -- FIFO 1 M_AXIS receiver (testbench to DUT) not ready
test_num <= 0;

-- Asynchronous reset
axi_reset_n <= '0';
wait for 55 ns;
axi_reset_n <= '1';

wait until rising_edge(clk);
wait for CLOCK_PERIOD*10;


----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- SIMULATE AXI Stream Pass-through (write data, stream through)
----------------------------------------------------------------------------
spi_axis_ready <= '1';  -- FIFO 1 M_AXIS receiver (testbench to DUT) ready
----------------------------------------------------------------------------
-- TEST 1: AXI Stream Handshake with TREADY asserted before TVALID
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)

axi_reset_n <= '0';
wait for CLOCK_PERIOD*2;
axi_reset_n <= '1';

wait until fifo_0_axis_ready = '1';
wait for CLOCK_PERIOD;
enable_stream <= '1';       -- start AXI stream write process, assert TVALID
wait for CLOCK_PERIOD*100;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD;


----------------------------------------------------------------------------
-- TEST 2: AXI Stream Handshake with TVALID and TREADY asserted simultaneously
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)

axi_reset_n <= '0';         -- reset to force FIFO 0 S_AXIS interface TREADY low
enable_stream <= '1';       -- start AXI stream write process, assert TVALID next rising edge
wait for CLOCK_PERIOD;
axi_reset_n <= '1';         -- after reset, S_AXIS will assert TREADY 
wait for CLOCK_PERIOD*100;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD;

----------------------------------------------------------------------------
-- TEST 3: AXI Stream Handshake with TVALID asserted before TREADY
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)

-- Fill the FIFO buffer
spi_axis_ready <= '0';      -- FIFO 1 M_AXIS receiver (testbench to DUT) not ready
enable_stream <= '1';       -- start AXI stream write process
wait for CLOCK_PERIOD;
wait until fifo_0_axis_ready = '0';     -- wait for TREADY signal to fall low
wait for CLOCK_PERIOD*10;

-- Read data from FIFO
spi_axis_ready <= '1';      -- FIFO 1 M_AXIS receiver (testbench to DUT) ready
wait for CLOCK_PERIOD*100;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD*100;


std.env.stop;

end process stim_proc;

----------------------------------------------------------------------------

end testbench;