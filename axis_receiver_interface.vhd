----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: AXI Stream FIFO Controller/Responder Interface 
----------------------------------------------------------------------------
-- Library Declarations
library ieee;
use ieee.std_logic_1164.all;

----------------------------------------------------------------------------
-- Entity definition
entity axis_receiver_interface is
	generic (
		DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24
	);
	port (
	   lrclk_i : in std_logic;
	   left_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   right_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   

		-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic
	);
end axis_receiver_interface;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of axis_receiver_interface is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal axis_tready                      : std_logic := '1';
signal axis_left_data, axis_right_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
signal data_rx                          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0'); 

type state_type is (Idle, Right, Left);
signal curr_state, next_state : state_type := Idle;
----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------  
component flipflop is
        generic(AC_DATA_WIDTH : integer := 24);
        port (
            clk_i        : in  std_logic;
            async_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
            sync_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0)
        );
end component;

----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------
  left_sync_inst : flipflop
        port map (
            clk_i        => lrclk_i,
            async_data_i => axis_left_data(AC_DATA_WIDTH-1 downto 0),
            sync_data_o  => left_audio_data_o
        );
  right_sync_inst_2 : flipflop
    port map (
        clk_i        => lrclk_i,
        async_data_i => axis_right_data(AC_DATA_WIDTH-1 downto 0),
        sync_data_o  => right_audio_data_o
    );
----------------------------------------------------------------------------
-- Logic
----------------------------------------------------------------------------  
axi_stream_logic : process(s00_axis_aclk)
begin
    if rising_edge(s00_axis_aclk) then 
        data_rx <= s00_axis_tdata;
    end if;
end process;


async_proc : process(s00_axis_tvalid, axis_tready, s00_axis_tdata) 
begin 
           if s00_axis_tvalid = '1' and axis_tready = '1' then
            if data_rx(DATA_WIDTH - 1) = '1' then
                axis_left_data <= data_rx;

            elsif data_rx(DATA_WIDTH - 1) = '0' then
                axis_right_data <= data_rx;
            end if;
         end if;
end process; 

s00_axis_tready <= axis_tready;


end Behavioral;

