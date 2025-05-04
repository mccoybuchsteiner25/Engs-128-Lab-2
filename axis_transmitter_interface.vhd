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
entity axis_transmitter_interface is
	generic (
		DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24
	);
	port (
	   lrclk_i : in std_logic;
	   left_audio_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   right_audio_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
	   

		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic
	);
end axis_transmitter_interface;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of axis_transmitter_interface is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal axis_tvalid                      : std_logic := '0';
signal axis_left_data, axis_right_data  : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal data_tx                          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0'); 


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

m00_axis_tvalid <= axis_tvalid;
----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------   
left_data_sync : flipflop
port map (
    clk_i        => m00_axis_aclk,
    async_data_i => left_audio_data_i,
    sync_data_o  => axis_left_data
);

right_data_sync : flipflop 
port map (
    clk_i        => m00_axis_aclk,
    async_data_i => right_audio_data_i,
    sync_data_o  => axis_right_data
);
----------------------------------------------------------------------------
-- Logic
----------------------------------------------------------------------------  
axi_stream_logic : process(m00_axis_aclk)
begin
    if rising_edge(m00_axis_aclk) then 
        if m00_axis_tready = '1' and axis_tvalid ='1' then
            m00_axis_tdata <= data_tx;
         end if;
    end if;
end process;


state_update: process(m00_axis_aclk)
begin
    if (falling_edge(m00_axis_aclk)) then
        curr_state <= next_state;
    end if;
end process state_update;


next_state_logic : process(curr_state, lrclk_i)
begin
    -- Default
    next_state <= curr_state;
    
    case curr_state is
        when Idle =>
            if lrclk_i='0' then
                next_state <= Left;
            elsif lrclk_i='1' then
                next_state <= Right;
            end if;

        when Left =>
            if lrclk_i='0' then
                next_state <= Left;
            elsif lrclk_i='1' then
                next_state <= Right;
            else
                next_state <= Idle;
            end if;
        when Right =>
            if lrclk_i='0' then
                next_state <= Left;
            elsif lrclk_i='1' then
                next_state <= Right;
            else
                next_state <= Idle;
            end if;
        when others =>
            next_state <= Idle;           
     end case;
end process next_state_logic;


output_logic: process(curr_state)
begin
    axis_tvalid <= '0';
    case curr_state is
        when Left =>
            data_tx <= "10000000" & axis_left_data;
            axis_tvalid <= '1';
        when Right =>
            data_tx <= "00000000" & axis_right_data;
            axis_tvalid <= '1';
        when others =>    
    end case;
    
end process output_logic;


end Behavioral;

