
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;



entity PModRS232 is
    Port ( 
      Clk      : in  std_logic;

      DataIn   : in  std_logic_vector(7 downto 0);
      DataOut  : out std_logic_vector(7 downto 0);
      Read     : in  std_logic;
      Write    : in  std_logic;
      DataRdy  : out std_logic;

      P3       : in  std_logic;
      P4       : out std_logic);
end PModRS232;

architecture Behavioral of PModRS232 is

-- 9600 baud rate period is 104,16us 
-- using 100kHz (10us) Clock need 10 periods, 100us
constant BAUD9600 : std_logic_vector(3 downto 0) := x"9";

signal baud  : std_logic_vector(3 downto 0) := x"0";

signal data : std_logic_vector(7 downto 0) := x"00";

signal state : std_logic_vector(3 downto 0) := x"0";

signal idle, done, TXD, RXD, cycle : std_logic;

signal prevTXD : std_logic := '1';

signal reqWrite, shift : std_logic := '0';


begin
   
   -- pin mapping
   TXD <= P3;
   P4 <= RXD;
   
   DataOut <= data;
   
   RXD <= 
      -- drive back TXD when not sending data
      TXD when idle = '1' or reqWrite = '0' else 
      -- start signal
      '0' when state = x"0" else
      -- send serialized the byte
      data(0) when shift = '1' else
      -- signal stop
      '1';
   
   -- 1 start + 8 data + 2 stop bits
   idle <= '1' when state = x"B" else '0';
   
   cycle <= '1' when baud = x"0" else '0';
   
   process(Clk)
   begin
      if rising_edge(Clk) then
         prevTXD <= TXD;
         
         -- handshake EPP module
         if Read = '1' or (reqWrite = '1' and idle = '1') then
            DataRdy <= '1';
         else
            DataRdy <= '0';
         end if;

         -- set flag for Write Request
         if Write = '1' then
            reqWrite <= '1';
         elsif idle = '1' then
            reqWrite <= '0';
         end if;
         
         -- load the shift register with data byte from EPP
         if Write = '1' then
            data <= DataIn;
         elsif shift = '1' and cycle = '1' then
            data <= TXD & data(7 downto 1);
         end if;
         
         -- enable serialization
         if cycle = '1' then
            if state = x"0" then
               shift <= '1';
            elsif state = x"8" then
               shift <= '0';
            end if;
         end if;
         
         -- start serialization to send or receive a data byte 
         -- to receive:
         --   detect start bit, falling edge on TXD
         --   to read in the middle of the bits
         --   load the counter with the half of a bit length
         if Write = '1' or (idle = '1' and prevTXD = '1' and TXD = '0') then
            state <= "0000";
            if Write = '1' then
               baud <= BAUD9600;
            else
               baud <= '0' & BAUD9600(3 downto 1);
            end if;
         elsif idle = '0' then
            if cycle = '1' then
               state <= state + '1';
               baud <= BAUD9600;
            else
               baud <= baud - '1';
            end if;
         end if;
         
         
      end if;         
   end process;
 
 
end Behavioral;
