----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: AXI stream wrapper for controlling I2S audio data flow
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;                                    
----------------------------------------------------------------------------
-- Entity definition
entity axis_i2s_wrapper is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32
	);
    Port ( 
        ----------------------------------------------------------------------------
        -- Fabric clock from Zynq PS
		sysclk_i : in  std_logic;	
		
        ----------------------------------------------------------------------------
        -- I2S audio codec ports		
		-- User controls
		ac_mute_en_i : in STD_LOGIC;
		
		-- Audio Codec I2S controls
        ac_bclk_o : out STD_LOGIC;
        ac_mclk_o : out STD_LOGIC;
        ac_mute_n_o : out STD_LOGIC;	-- Active Low
        
        -- Audio Codec DAC (audio out)
        ac_dac_data_o : out STD_LOGIC;
        ac_dac_lrclk_o : out STD_LOGIC;
        
        -- Audio Codec ADC (audio in)
        ac_adc_data_i : in STD_LOGIC;
        ac_adc_lrclk_o : out STD_LOGIC;
        dbg_left_audio_rx_o : out std_logic_vector(23 downto 0); --left audio rx from codec 
        dbg_left_audio_tx_o : out std_logic_vector(23 downto 0); --left audio tx from codec
        dbg_right_audio_rx_o : out std_logic_vector(23 downto 0); --right audio rx from codec
        dbg_right_audio_tx_o : out std_logic_vector(23 downto 0); --right audio tx from codec 
        
        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;
		
        -- AXI Stream Interface (Tranmitter/Controller)
		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic);
end axis_i2s_wrapper;
----------------------------------------------------------------------------
architecture Behavioral of axis_i2s_wrapper is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------     
signal mclk_s		      : std_logic := '0';	
signal bclk_s            : std_logic := '0';
signal lrclk_s           : std_logic := '0';
signal left_audio_data_tx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_tx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal left_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal ac_mute_n_s : std_logic := '0';
signal ac_mute_n_reg_s : std_logic := '0';

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- Clock generation
component i2s_clock_gen is
    Port ( 
          --sysclk_125MHz_i : in std_logic; --comment for implementation 
          mclk_i : in std_logic;
          mclk_fwd_o : out std_logic;  
          bclk_fwd_o : out std_logic;
          adc_lrclk_fwd_o : out std_logic;
          dac_lrclk_fwd_o : out std_logic;
        
--           mclk_o    : out std_logic; -- 12.288 MHz output of clk_wiz	, comment for implementation
		   bclk_o    : out std_logic;	
		   lrclk_o   : out std_logic); 
end component i2s_clock_gen;

---------------------------------------------------------------------------- 
-- I2S receiver
component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (

        -- Timing
--		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		adc_serial_data_i     : in std_logic;
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0')
		);  
end component i2s_receiver;
	
---------------------------------------------------------------------------- 
-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (

        -- Timing
--		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end component i2s_transmitter;

---------------------------------------------------------------------------- 
-- AXI stream transmitter
component axis_transmitter_interface is
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
end component axis_transmitter_interface;

---------------------------------------------------------------------------- 
-- AXI stream receiver 
component axis_receiver_interface is
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
end component axis_receiver_interface;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
-- Clock generation
clk_gen : i2s_clock_gen
    port map (
          --sysclk_125MHz_i => sysclk_i,
          mclk_i => sysclk_i,
          mclk_fwd_o => ac_mclk_o,
          bclk_fwd_o => ac_bclk_o,
          adc_lrclk_fwd_o => ac_adc_lrclk_o,
          dac_lrclk_fwd_o => ac_dac_lrclk_o,
          --mclk_o => mclk_s,
          bclk_o => bclk_s,
          lrclk_o => lrclk_s
    );
---------------------------------------------------------------------------- 
-- I2S receiver
audio_receiver : i2s_receiver
    generic map (
        AC_DATA_WIDTH => 24
    )
    port map (
--        mclk_i => sysclk_i,
--        mclk_i => mclk_s,
        bclk_i => bclk_s,
        lrclk_i => lrclk_s,
        adc_serial_data_i => ac_adc_data_i,
        left_audio_data_o => left_audio_data_s,
        right_audio_data_o => right_audio_data_s
    );
	
---------------------------------------------------------------------------- 
-- I2S transmitter
audio_transmitter : i2s_transmitter
    generic map (
        AC_DATA_WIDTH => 24
    )
    port map (
 --       mclk_i => sysclk_i,
 --       mclk_i => mclk_s,
        bclk_i => bclk_s,
        lrclk_i => lrclk_s,
        left_audio_data_i => left_audio_data_tx_s,
        right_audio_data_i => right_audio_data_tx_s,
        dac_serial_data_o => ac_dac_data_o
    );

---------------------------------------------------------------------------- 
-- AXI stream transmitter
axis_transmitter : axis_transmitter_interface
    generic map (
        DATA_WIDTH => C_AXI_STREAM_DATA_WIDTH,
        AC_DATA_WIDTH => 24
    )
    port map (
        left_audio_data_i => left_audio_data_s,
        right_audio_data_i => right_audio_data_s,
        lrclk_i => lrclk_s,
        m00_axis_aclk => m00_axis_aclk,
        m00_axis_aresetn => m00_axis_aresetn,
        m00_axis_tvalid => m00_axis_tvalid,
        m00_axis_tdata => m00_axis_tdata,
        m00_axis_tstrb => m00_axis_tstrb,
        m00_axis_tlast => m00_axis_tlast,
        m00_axis_tready => m00_axis_tready
    );
    

---------------------------------------------------------------------------- 
-- AXI stream receiver
axis_receiver : axis_receiver_interface
    generic map (
        DATA_WIDTH => C_AXI_STREAM_DATA_WIDTH,
        AC_DATA_WIDTH => 24
    )
    port map (
        left_audio_data_o => left_audio_data_tx_s,
        right_audio_data_o => right_audio_data_tx_s,
        lrclk_i => lrclk_s,
        s00_axis_aclk => s00_axis_aclk,
        s00_axis_aresetn => s00_axis_aresetn,
        s00_axis_tready => s00_axis_tready,
        s00_axis_tdata => s00_axis_tdata,
        s00_axis_tstrb => s00_axis_tstrb,
        s00_axis_tlast => s00_axis_tlast,
        s00_axis_tvalid => s00_axis_tvalid
    );
    
---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 
dbg_left_audio_rx_o <= left_audio_data_s;
dbg_left_audio_tx_o <= left_audio_data_tx_s;
dbg_right_audio_rx_o <= right_audio_data_s;
dbg_right_audio_tx_o <= right_audio_data_tx_s; 



ac_mute_n_s <= not ac_mute_en_i;
mute_process : process(sysclk_i)
begin
    if rising_edge(sysclk_i) then
        ac_mute_n_reg_s <= ac_mute_n_s;
    end if;
end process;
ac_mute_n_o <= ac_mute_n_reg_s;
----------------------------------------------------------------------------


end Behavioral;
