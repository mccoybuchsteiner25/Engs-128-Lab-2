----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for AXI stream interface
--      NOTES: TSTRB = HIGH (all bytes are valid data)
--             TLAST = LOW (all data packets are part of the same stream)
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity Declaration
entity tb_axi_stream_interface is
end tb_axi_stream_interface;

----------------------------------------------------------------------------
architecture testbench of tb_axi_stream_interface is
----------------------------------------------------------------------------
-- Constants
constant AXI_DATA_WIDTH : integer := 8;         -- AXI data bus
constant AXI_FIFO_DEPTH : integer := 12;        -- AXI stream FIFO depth
constant CLOCK_PERIOD : time := 8ns;            -- 125 MHz clock

-- Signal declarations
signal clk : std_logic := '0';
signal reset_n : std_logic := '1';
signal enable_stream : std_logic := '0';
signal test_num : integer := 0;

-- AXI Stream
signal M_AXIS_TDATA, S_AXIS_TDATA : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal M_AXIS_TSTRB, S_AXIS_TSTRB : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
signal M_AXIS_TVALID, S_AXIS_TVALID : std_logic := '0';
signal M_AXIS_TREADY, S_AXIS_TREADY : std_logic := '0';
signal M_AXIS_TLAST, S_AXIS_TLAST : std_logic := '0';

----------------------------------------------------------------------------
-- AXI stream component
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
end component axis_fifo;

----------------------------------------------------------------------------------
begin
----------------------------------------------------------------------------------
-- Instantiate dut
dut: axis_fifo
port map (
  
    s00_axis_aclk => clk,
    s00_axis_aresetn => reset_n,
    s00_axis_tready => S_AXIS_TREADY,
    s00_axis_tdata => S_AXIS_TDATA,
    s00_axis_tstrb => S_AXIS_TSTRB,
    s00_axis_tlast => S_AXIS_TLAST,
    s00_axis_tvalid => S_AXIS_TVALID, 

    m00_axis_aclk => clk,
    m00_axis_aresetn => reset_n,
    m00_axis_tvalid => M_AXIS_TVALID,
    m00_axis_tdata => M_AXIS_TDATA,
    m00_axis_tstrb => M_AXIS_TSTRB,
    m00_axis_tlast => M_AXIS_TLAST,
    m00_axis_tready => M_AXIS_TREADY);
    
----------------------------------------------------------------------------------
-- Clock generation
clock_gen_process : process
begin
	clk <= '0';				    -- start low
	wait for CLOCK_PERIOD;	    -- wait for one CLOCK_PERIOD
	
	loop							-- toggle, wait half a clock period, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;
   
   
----------------------------------------------------------------------------------
-- Initiate process which simulates a master controller wanting to write to AXI stream.
--      This process is blocked on a "Send Flag" (enable_stream).
--      When the flag goes to 1, the process exits the wait state and
--          execute a write transaction.
send_stream : process(reset_n, clk)
begin
    
    if reset_n = '0' then               -- asynchronous reset
        S_AXIS_TDATA <= std_logic_vector(to_unsigned(1,AXI_DATA_WIDTH));    -- start at some value
    elsif rising_edge(clk) then
        
        if enable_stream = '1' then
            S_AXIS_TVALID <= '1';
            if S_AXIS_TREADY = '1' then  -- send test data, increment value by one
                S_AXIS_TDATA <= std_logic_vector(unsigned(S_AXIS_TDATA) + 1);
            end if;
        else
            S_AXIS_TVALID <= '0';
        end if;  
    
    end if;
    
end process send_stream;
----------------------------------------------------------------------------------
S_AXIS_TSTRB <= (others => '1');    -- all bytes contain valid data
S_AXIS_TLAST <= '0';                -- all data is part of the same stream

----------------------------------------------------------------------------------
-- Stimulus process
----------------------------------------------------------------------------------
stim_proc : process
begin

-- Initialize
enable_stream <= '0';   -- Disable data into S_AXIS interface (testbench to DUT) 
M_AXIS_TREADY <= '0';   -- M_AXIS receiver (testbench to DUT) not ready
test_num <= 0;

-- Asynchronous reset
reset_n <= '0';
wait for 55 ns;
reset_n <= '1';

wait until rising_edge(clk);
wait for CLOCK_PERIOD*10;

----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- TEST 1: AXI Stream Pass-through (write data, stream through)
----------------------------------------------------------------------------
M_AXIS_TREADY <= '1';       -- M_AXIS receiver (testbench to DUT) ready
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)

reset_n <= '0';             -- reset to force S_AXIS interface TREADY low
enable_stream <= '1';       -- start AXI stream write process, assert TVALID next rising edge
wait for CLOCK_PERIOD;
reset_n <= '1';             -- after reset, S_AXIS will assert TREADY 
wait for CLOCK_PERIOD*100;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD;

----------------------------------------------------------------------------
-- Reset before testing next condition
----------------------------------------------------------------------------
reset_n <= '0';
wait for CLOCK_PERIOD*2;
reset_n <= '1';

----------------------------------------------------------------------------
-- TEST 2: AXI Stream Handshake with TVALID asserted before TREADY
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)

M_AXIS_TREADY <= '0';       -- M_AXIS receiver (testbench to DUT) not ready
enable_stream <= '1';       -- start AXI stream write process, assert TVALID
wait until M_AXIS_TVALID = '1';     -- wait for TVALID
wait for CLOCK_PERIOD;      -- wait one clock period
M_AXIS_TREADY <= '1';       -- M_AXIS receiver (testbench to DUT) ready
wait for CLOCK_PERIOD;      -- wait one clock period for data transfer to occur
M_AXIS_TREADY <= '0';       -- M_AXIS receiver (testbench to DUT) not ready
wait for CLOCK_PERIOD*10;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD;

----------------------------------------------------------------------------
-- Reset before testing next condition
----------------------------------------------------------------------------
reset_n <= '0';
wait for CLOCK_PERIOD*2;
reset_n <= '1';

----------------------------------------------------------------------------
-- TEST 3: AXI Stream Handshake with TREADY asserted before TVALID
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)
M_AXIS_TREADY <= '1';       -- M_AXIS receiver (testbench to DUT) ready
wait for CLOCK_PERIOD;
enable_stream <= '1';       -- start AXI stream write process, assert TVALID
wait until M_AXIS_TVALID = '1';     -- wait for TVALID
wait for CLOCK_PERIOD;
enable_stream <= '0';       -- stop stream
M_AXIS_TREADY <= '0';       -- M_AXIS receiver (testbench to DUT) not ready
wait for CLOCK_PERIOD;

----------------------------------------------------------------------------
-- Reset before testing next condition
----------------------------------------------------------------------------
reset_n <= '0';
wait for CLOCK_PERIOD*2;
reset_n <= '1';

----------------------------------------------------------------------------
-- TEST 4: AXI Stream Handshake with TVALID and TREADY asserted simultaneously
----------------------------------------------------------------------------
wait until rising_edge(clk);
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)
enable_stream <= '1';       -- start AXI stream write process, assert TVALID next rising edge
wait until M_AXIS_TVALID = '1';     -- wait for TVALID
M_AXIS_TREADY <= '1';       -- M_AXIS receiver (testbench to DUT) ready
wait for CLOCK_PERIOD*100;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD;
wait until rising_edge(clk);

----------------------------------------------------------------------------
-- Reset before testing next condition
----------------------------------------------------------------------------
reset_n <= '0';
wait for CLOCK_PERIOD*2;
reset_n <= '1';

----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- TEST 5: AXI Stream Write (write data, save to FIFO buffer)
----------------------------------------------------------------------------
M_AXIS_TREADY <= '0';       -- M_AXIS receiver (testbench to DUT) not ready
----------------------------------------------------------------------------
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)
wait for CLOCK_PERIOD;
enable_stream <= '1';       -- start AXI stream write process, assert TVALID
wait for CLOCK_PERIOD*100;
enable_stream <= '0';       -- stop stream
wait for CLOCK_PERIOD;
wait until rising_edge(clk);

----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- TEST 6: AXI Stream Read (read data from FIFO buffer)
----------------------------------------------------------------------------
M_AXIS_TREADY <= '1';       -- M_AXIS receiver (testbench to DUT) ready
----------------------------------------------------------------------------
test_num <= test_num + 1;   -- increment test number (use to track in sim waveform)

wait for CLOCK_PERIOD*10;
wait until M_AXIS_TVALID = '0';


wait for CLOCK_PERIOD*100;

std.env.stop;
end process stim_proc;
----------------------------------------------------------------------------

end testbench;
