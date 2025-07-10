library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PingPong is
    Port ( 
        Clk : in STD_LOGIC;
        SW0 : in STD_LOGIC; -- Reset switch
        SW1 : in STD_LOGIC; -- Player 1 control switch
        SW2 : in STD_LOGIC; -- Player 2 control switch
        SW3 : in STD_LOGIC; -- Additional switch (e.g., pause)
        VGA_HSync : out STD_LOGIC;
        VGA_VSync : out STD_LOGIC;
        VGA_Red : out STD_LOGIC_VECTOR (7 downto 0);
        VGA_Green : out STD_LOGIC_VECTOR (7 downto 0);
        VGA_Blue : out STD_LOGIC_VECTOR (7 downto 0);
        DAC_CLK : out STD_LOGIC -- DAC clock output
    );
end PingPong;

architecture Behavioral of PingPong is
    -- VGA Timing Constants
    constant H_FRONT_PORCH : integer := 16;
    constant H_TOTAL : integer := 800;
    constant H_SYNC_PULSE : integer := 96;
    constant V_FRONT_PORCH : integer := 10;
    constant V_TOTAL : integer := 525;
    constant V_SYNC_PULSE : integer := 2;
    
    -- Clock Generation Signals
    signal Clock_Divider : STD_LOGIC := '0';
    signal Clock_Counter : integer := 0;

    -- Pixel Display Signals
    signal Video_On : STD_LOGIC;
    signal Horizontal_Counter : integer := 0;
    signal Vertical_Counter : integer := 0;

    -- Game State Signals
    signal Player1_X : integer := 50; -- Player 1 X position
    signal Player1_Y : integer := 360; -- Player 1 Y position
    signal Player2_X : integer := 580; -- Player 2 X position
    signal Player2_Y : integer := 60;  -- Player 2 Y position
    signal Ball_X : integer := 310;    -- Ball X position
    signal Ball_Y : integer := 230;    -- Ball Y position (center)
    signal Ball_H_Direction : STD_LOGIC := '0'; -- Ball horizontal direction (0 = right, 1 = left)
    signal Ball_V_Direction : STD_LOGIC := '0'; -- Ball vertical direction (0 = down, 1 = up)

    -- Ball color
    signal Ball_Color : STD_LOGIC_VECTOR(7 downto 0) := "11111100"; -- Yellow, initially

    -- Constants for game logic
    constant PADDLE_HEIGHT : integer := 80;  -- Height of the paddle
    constant BALL_SIZE : integer := 10;      -- Size of the ball
    constant PADDLE_SPEED : integer := 1;    -- Speed of paddle movement
    constant BALL_SPEED_X : integer := 1;    -- Horizontal speed of the ball
    constant BALL_SPEED_Y : integer := 1;    -- Vertical speed of the ball
    constant MAX_Y : integer := 480;         -- Maximum Y coordinate
    constant MAX_X : integer := 640;         -- Maximum X coordinate
    constant PADDLE_WIDTH : integer := 10;   -- Width of the paddle (added this constant)

    -- Initialize RGB color
    signal RGB : STD_LOGIC_VECTOR(7 downto 0) := "00000000"; -- Initialize to black

begin
    -- Clock Divider for Pixel Clock
    Clock_Divider_Process : process(Clk)
    begin
        if rising_edge(Clk) then
            Clock_Counter <= Clock_Counter + 1;
            if Clock_Counter >= 4 then  -- Divide by 4 to generate pixel clock
                Clock_Divider <= not Clock_Divider;
                Clock_Counter <= 0;
            end if;
        end if;
    end process Clock_Divider_Process;

    -- VGA Sync Signal Generation
    VGA_Sync_Generation : process(Clock_Divider)
    begin
        if rising_edge(Clock_Divider) then
            -- Horizontal sync and counter
            if Horizontal_Counter < H_TOTAL - 1 then
                Horizontal_Counter <= Horizontal_Counter + 1;
            else
                Horizontal_Counter <= 0;
            end if;

            -- Vertical sync and counter
            if Vertical_Counter < V_TOTAL - 1 then
                Vertical_Counter <= Vertical_Counter + 1;
            else
                Vertical_Counter <= 0;
            end if;

            -- Generate HSync and VSync signals
            if Horizontal_Counter < H_SYNC_PULSE then
                VGA_HSync <= '0';
            else
                VGA_HSync <= '1';
            end if;

            if Vertical_Counter < V_SYNC_PULSE then
                VGA_VSync <= '0';
            else
                VGA_VSync <= '1';
            end if;

            -- Adjust for front porch, back porch, and active image area
            if Horizontal_Counter < H_FRONT_PORCH or Horizontal_Counter >= MAX_X then
                VGA_HSync <= '1'; -- Set HSync during front porch and back porch
            end if;

            if Vertical_Counter < V_FRONT_PORCH or Vertical_Counter >= MAX_Y then
                VGA_VSync <= '1'; -- Set VSync during front porch and back porch
            end if;
        end if;
    end process VGA_Sync_Generation;

    -- Game Logic Process
    Game_Logic_Process : process(Clk)
    begin
        if rising_edge(Clk) then
            -- Reset Game State
            if SW0 = '1' then
                Player1_Y <= 360;
                Player2_Y <= 60;
                Ball_X <= 310;
                Ball_Y <= 230;
                Ball_H_Direction <= '0';
                Ball_V_Direction <= '0';
                Ball_Color <= "11111100"; -- Yellow
            end if;

            -- Player 1 Movement
            if SW1 = '1' then
                if Player1_Y > 0 then
                    Player1_Y <= Player1_Y - PADDLE_SPEED;
                end if;
            elsif SW2 = '1' then
                if Player1_Y < MAX_Y - PADDLE_HEIGHT then
                    Player1_Y <= Player1_Y + PADDLE_SPEED;
                end if;
            end if;

            -- Ball Movement
            if Ball_H_Direction = '0' then
                Ball_X <= Ball_X + BALL_SPEED_X;
            else
                Ball_X <= Ball_X - BALL_SPEED_X;
            end if;

            if Ball_V_Direction = '0' then
                Ball_Y <= Ball_Y + BALL_SPEED_Y;
            else
                Ball_Y <= Ball_Y - BALL_SPEED_Y;
            end if;

            -- Ball Collision with Paddles
            if (Ball_X <= Player1_X + PADDLE_WIDTH) and (Ball_Y >= Player1_Y) and (Ball_Y <= Player1_Y + PADDLE_HEIGHT) then
                Ball_H_Direction <= '0';
                -- Change ball color to red when it hits the paddle
                Ball_Color <= "11110000"; -- Red
            end if;

            if (Ball_X + BALL_SIZE >= Player2_X) and (Ball_Y >= Player2_Y) and (Ball_Y <= Player2_Y + PADDLE_HEIGHT) then
                Ball_H_Direction <= '1';
                -- Change ball color to blue when it hits the paddle
                Ball_Color <= "00001111"; -- Blue
            end if;

            -- Ball Collision with Top and Bottom Walls
            if Ball_Y <= 0 or Ball_Y >= MAX_Y - 1 then
                Ball_V_Direction <= not Ball_V_Direction;
            end if;

            -- Ball Out of Bounds
            if Ball_X <= 0 or Ball_X >= MAX_X - 1 then
                Ball_X <= 310;
                Ball_Y <= 230;
                Ball_H_Direction <= '0';
                Ball_V_Direction <= '0';
                Ball_Color <= "11111100"; -- Yellow
            end if;
        end if;
    end process Game_Logic_Process;

    -- DAC Clock Output
    DAC_CLK <= Clk; -- You can replace this with the actual DAC clock signal generation

    -- Pixel Coloring Process
    Pixel_Coloring : process(Horizontal_Counter, Vertical_Counter, Ball_X, Ball_Y, Ball_Color, Player1_X, Player1_Y, Player2_X, Player2_Y)
    begin
        -- Initialize RGB to black
        RGB <= "00000000";
        
        -- Check if within active image area
        if Horizontal_Counter < MAX_X and Vertical_Counter < MAX_Y then
            -- Check if the pixel is within the ball area
            if Ball_X <= Horizontal_Counter and Horizontal_Counter <= Ball_X + BALL_SIZE - 1
            and Ball_Y <= Vertical_Counter and Vertical_Counter <= Ball_Y + BALL_SIZE - 1 then
                RGB <= Ball_Color; -- Set pixel color to ball color
            elsif Horizontal_Counter <= Player1_X + PADDLE_WIDTH - 1 and Player1_Y <= Vertical_Counter and Vertical_Counter <= Player1_Y + PADDLE_HEIGHT - 1 then
                RGB <= "11110000"; -- Set pixel color to red for Player 1 paddle
            elsif Horizontal_Counter >= Player2_X and Player2_Y <= Vertical_Counter and Vertical_Counter <= Player2_Y + PADDLE_HEIGHT - 1 then
                RGB <= "00001111"; -- Set pixel color to blue for Player 2 paddle
            end if;
        end if;
        
        -- Output RGB values
        -- Output RGB values (adjusted for VGA signal sizes)
VGA_Red <= RGB(7 downto 5);
VGA_Green <= RGB(4 downto 2);
VGA_Blue <= RGB(1 downto 0);

    end process Pixel_Coloring;
end Behavioral;
