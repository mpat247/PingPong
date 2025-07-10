-------------------------------------------------------------------------------
-- PingPong.vhd
-- 
-- A VHDL implementation of a Pong game for Xilinx Spartan-3E FPGA. 
-- Features:
--   • Clock division to generate pixel clock 
--   • VGA synchronization (HS/VS) with front/back-porch handling 
--   • Two-player paddle control via switches 
--   • Ball movement, collision detection, and color changes 
--   • Reset and optional pause switch 
--   • DAC clock passthrough
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- Non-standard Arith/Unsigned libraries (enabled with -fsynopsys flag)
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PingPong is
    Port (
        -- System inputs
        sys_clk      : in  STD_LOGIC;              -- 50 MHz board clock
        reset_btn    : in  STD_LOGIC;              -- Active-high reset
        p1_up_btn    : in  STD_LOGIC;              -- Player 1 move up
        p1_down_btn  : in  STD_LOGIC;              -- Player 1 move down
        pause_btn    : in  STD_LOGIC;              -- Pause or unused switch

        -- VGA outputs
        vga_hs       : out STD_LOGIC;              -- Horizontal sync
        vga_vs       : out STD_LOGIC;              -- Vertical sync
        vga_r        : out STD_LOGIC_VECTOR(7 downto 0);  -- Red channel
        vga_g        : out STD_LOGIC_VECTOR(7 downto 0);  -- Green channel
        vga_b        : out STD_LOGIC_VECTOR(7 downto 0);  -- Blue channel

        -- DAC clock output
        dac_clk_out  : out STD_LOGIC               -- Passthrough of sys_clk
    );
end PingPong;

architecture Behavioral of PingPong is

    ----------------------------------------------------------------------------
    -- VGA timing parameters
    ----------------------------------------------------------------------------
    constant H_ACTIVE_PIXELS    : integer := 640;  -- Visible horizontal pixels
    constant H_FRONT_PORCH      : integer := 16;   -- Front porch
    constant H_SYNC_PULSE       : integer := 96;   -- HS pulse width
    constant H_BACK_PORCH       : integer := 800 - H_ACTIVE_PIXELS - H_SYNC_PULSE - H_FRONT_PORCH;
    constant H_TOTAL            : integer := 800;  -- Total horizontal clocks

    constant V_ACTIVE_LINES     : integer := 480;  -- Visible vertical lines
    constant V_FRONT_PORCH      : integer := 10;   -- Front porch
    constant V_SYNC_PULSE       : integer := 2;    -- VS pulse width
    constant V_BACK_PORCH       : integer := 525 - V_ACTIVE_LINES - V_SYNC_PULSE - V_FRONT_PORCH;
    constant V_TOTAL            : integer := 525;  -- Total vertical clocks

    ----------------------------------------------------------------------------
    -- Game constants
    ----------------------------------------------------------------------------
    constant PADDLE_HEIGHT      : integer := 80;    -- Paddle vertical size
    constant PADDLE_WIDTH       : integer := 10;    -- Paddle horizontal thickness
    constant BALL_SIZE          : integer := 10;    -- Ball square size
    constant PADDLE_MOVE_SPEED  : integer := 1;     -- Pixels per update
    constant BALL_SPEED_X       : integer := 1;     -- Horizontal ball speed
    constant BALL_SPEED_Y       : integer := 1;     -- Vertical ball speed

    ----------------------------------------------------------------------------
    -- Clock division to generate pixel clock (~12.5 MHz if sys_clk = 50 MHz)
    ----------------------------------------------------------------------------
    signal pixel_clk        : STD_LOGIC := '0';
    signal clk_div_counter  : integer    := 0;

    ----------------------------------------------------------------------------
    -- VGA coordinate counters
    ----------------------------------------------------------------------------
    signal h_counter        : integer := 0;
    signal v_counter        : integer := 0;

    ----------------------------------------------------------------------------
    -- Game state signals
    ----------------------------------------------------------------------------
    signal p1_y_pos         : integer := (V_ACTIVE_LINES - PADDLE_HEIGHT) / 2;  -- Center start
    signal p2_y_pos         : integer := (V_ACTIVE_LINES - PADDLE_HEIGHT) / 2;
    constant p1_x_pos       : integer := 50;   -- Fixed X for left paddle
    constant p2_x_pos       : integer := 580;  -- Fixed X for right paddle

    signal ball_x_pos       : integer := (H_ACTIVE_PIXELS - BALL_SIZE) / 2;
    signal ball_y_pos       : integer := (V_ACTIVE_LINES - BALL_SIZE) / 2;
    signal ball_dir_x       : STD_LOGIC := '0';  -- '0' = moving right, '1' = left
    signal ball_dir_y       : STD_LOGIC := '0';  -- '0' = moving down, '1' = up

    signal ball_color       : STD_LOGIC_VECTOR(7 downto 0) := "11111100";  -- Yellow
    signal pixel_color      : STD_LOGIC_VECTOR(7 downto 0);

begin

    ----------------------------------------------------------------------------
    -- Clock Divider Process: divides sys_clk by 4 for a ~12.5 MHz pixel clock
    ----------------------------------------------------------------------------
    clk_div_proc: process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if clk_div_counter = 3 then
                pixel_clk       <= not pixel_clk;
                clk_div_counter <= 0;
            else
                clk_div_counter <= clk_div_counter + 1;
            end if;
        end if;
    end process clk_div_proc;

    ----------------------------------------------------------------------------
    -- VGA Sync Generation: HS/VS, counters, and porches
    ----------------------------------------------------------------------------
    vga_sync_proc: process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            -- Horizontal counter
            if h_counter = H_TOTAL - 1 then
                h_counter <= 0;
                -- Vertical counter
                if v_counter = V_TOTAL - 1 then
                    v_counter <= 0;
                else
                    v_counter <= v_counter + 1;
                end if;
            else
                h_counter <= h_counter + 1;
            end if;

            -- Generate HS pulse (active low)
            if h_counter < H_SYNC_PULSE then
                vga_hs <= '0';
            else
                vga_hs <= '1';
            end if;

            -- Generate VS pulse (active low)
            if v_counter < V_SYNC_PULSE then
                vga_vs <= '0';
            else
                vga_vs <= '1';
            end if;
        end if;
    end process vga_sync_proc;

    ----------------------------------------------------------------------------
    -- Main Game Logic: reset, paddle move, ball move, collisions
    ----------------------------------------------------------------------------
    game_logic_proc: process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            -- Reset everything on reset_btn
            if reset_btn = '1' then
                p1_y_pos    <= (V_ACTIVE_LINES - PADDLE_HEIGHT) / 2;
                p2_y_pos    <= (V_ACTIVE_LINES - PADDLE_HEIGHT) / 2;
                ball_x_pos  <= (H_ACTIVE_PIXELS - BALL_SIZE) / 2;
                ball_y_pos  <= (V_ACTIVE_LINES - BALL_SIZE) / 2;
                ball_dir_x  <= '0';
                ball_dir_y  <= '0';
                ball_color  <= "11111100";  -- Yellow
            else
                -- Player 1 movement
                if p1_up_btn = '1' and p1_y_pos > 0 then
                    p1_y_pos <= p1_y_pos - PADDLE_MOVE_SPEED;
                elsif p1_down_btn = '1' and p1_y_pos < V_ACTIVE_LINES - PADDLE_HEIGHT then
                    p1_y_pos <= p1_y_pos + PADDLE_MOVE_SPEED;
                end if;

                -- (Add Player 2 controls here if desired)
                -- e.g., using pause_btn or other switches

                -- Ball horizontal movement
                if ball_dir_x = '0' then
                    ball_x_pos <= ball_x_pos + BALL_SPEED_X;
                else
                    ball_x_pos <= ball_x_pos - BALL_SPEED_X;
                end if;

                -- Ball vertical movement
                if ball_dir_y = '0' then
                    ball_y_pos <= ball_y_pos + BALL_SPEED_Y;
                else
                    ball_y_pos <= ball_y_pos - BALL_SPEED_Y;
                end if;

                -- Collision: left paddle
                if ball_x_pos <= p1_x_pos + PADDLE_WIDTH and
                   ball_y_pos >= p1_y_pos and
                   ball_y_pos <= p1_y_pos + PADDLE_HEIGHT then
                    ball_dir_x <= '0';                    -- Bounce right
                    ball_color <= "11110000";             -- Red on hit
                end if;

                -- Collision: right paddle
                if ball_x_pos + BALL_SIZE >= p2_x_pos and
                   ball_y_pos >= p2_y_pos and
                   ball_y_pos <= p2_y_pos + PADDLE_HEIGHT then
                    ball_dir_x <= '1';                    -- Bounce left
                    ball_color <= "00001111";             -- Blue on hit
                end if;

                -- Bounce off top/bottom
                if ball_y_pos = 0 or ball_y_pos + BALL_SIZE = V_ACTIVE_LINES then
                    ball_dir_y <= not ball_dir_y;
                end if;

                -- Reset ball if out of horizontal bounds
                if ball_x_pos = 0 or ball_x_pos + BALL_SIZE = H_ACTIVE_PIXELS then
                    ball_x_pos <= (H_ACTIVE_PIXELS - BALL_SIZE) / 2;
                    ball_y_pos <= (V_ACTIVE_LINES - BALL_SIZE) / 2;
                    ball_dir_x <= '0';
                    ball_dir_y <= '0';
                    ball_color <= "11111100";  -- Yellow
                end if;
            end if;
        end if;
    end process game_logic_proc;

    ----------------------------------------------------------------------------
    -- Pixel Coloring: decide RGB based on object positions each pixel clock
    ----------------------------------------------------------------------------
    pixel_gen_proc: process(h_counter, v_counter,
                             p1_x_pos, p1_y_pos,
                             p2_x_pos, p2_y_pos,
                             ball_x_pos, ball_y_pos, ball_color)
    begin
        -- Default to black
        pixel_color := (others => '0');

        -- Only draw within active area
        if h_counter < H_ACTIVE_PIXELS and v_counter < V_ACTIVE_LINES then

            -- Draw the ball
            if (h_counter >= ball_x_pos) and (h_counter < ball_x_pos + BALL_SIZE) and
               (v_counter >= ball_y_pos) and (v_counter < ball_y_pos + BALL_SIZE) then
                pixel_color := ball_color;

            -- Draw Player 1 paddle
            elsif (h_counter >= p1_x_pos) and (h_counter < p1_x_pos + PADDLE_WIDTH) and
                  (v_counter >= p1_y_pos) and (v_counter < p1_y_pos + PADDLE_HEIGHT) then
                pixel_color := "11110000";  -- Red

            -- Draw Player 2 paddle
            elsif (h_counter >= p2_x_pos) and (h_counter < p2_x_pos + PADDLE_WIDTH) and
                  (v_counter >= p2_y_pos) and (v_counter < p2_y_pos + PADDLE_HEIGHT) then
                pixel_color := "00001111";  -- Blue

            end if;
        end if;

        -- Map 8-bit pixel_color to VGA (3-bit R, 3-bit G, 2-bit B)
        vga_r  <= pixel_color(7 downto 5);
        vga_g  <= pixel_color(4 downto 2);
        vga_b  <= pixel_color(1 downto 0);
    end process pixel_gen_proc;

    -- Direct passthrough of system clock to DAC clock pin
    dac_clk_out <= sys_clk;

end Behavioral;
