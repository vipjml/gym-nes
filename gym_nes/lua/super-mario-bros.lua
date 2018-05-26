require 'nes_interface'

local time = 0
local x_pos = 0

-- Return the current level (0-indexed) (0 to 31)
function get_level()
    -- Read the world 0x075f as the base and add the level. there are 4 levels
    -- per world
    return memory.readbyte(0x075f) * 4 + memory.readbyte(0x075c)
end

-- Return the current world number (1 to 8)
function get_world_number()
    return memory.readbyte(0x075f) + 1
end

-- Return the current level number (1 to 4)
function get_level_number()
    return memory.readbyte(0x075c) + 1
end

-- Return the current area number (1 to 5)
function get_area_number()
    return memory.readbyte(0x0760) + 1
end

-- Return the current player score (0 to 999990)
function get_score()
    return tonumber(nes_readbyterange(0x07de, 6))
end

-- Return the time left (0 to 999)
function get_time()
    return tonumber(nes_readbyterange(0x07f8, 3))
end

-- Return the number of coins collected (0 to 99)
function get_coins()
    return tonumber(nes_readbyterange(0x07ed, 2))
end

-- Return the number of remaining lives
function get_life()
    return memory.readbyte(0x075a)
end

-- Return the current horizontal position
function get_x_position()
    -- add the current page 0x6d to the current x
    return memory.readbyte(0x6d) * 0x100 + memory.readbyte(0x86)
end

-- Return the number of pixels from the left of the screen
function get_left_x_position()
    -- subtract the left x position 0x071c from the current x 0x86
    return (memory.readbyte(0x86) - memory.readbyte(0x071c)) % 256
end

-- Return the current vertical position
function get_y_position()
    return memory.readbyte(0x03b8)
end

-- Return the current y viewport
-- 1 = in visible viewport
-- 0 = above viewport
-- > 1 below viewport (i.e. dead, falling down a hole)
-- up to 5 indicates falling into a hole
function get_y_viewport()
    return memory.readbyte(0x00b5)
end

-- Return the player status
-- 0 --> small Mario
-- 1 --> tall Mario
-- 2+ -> fireball Mario
function get_player_status()
    return memory.readbyte(0x0756)
end

-- Return the current player state:
-- 0x00 -> Leftmost of screen
-- 0x01 -> Climbing vine
-- 0x02 -> Entering reversed-L pipe
-- 0x03 -> Going down a pipe
-- 0x04 -> Auto-walk
-- 0x05 -> Auto-walk
-- 0x06 -> Dead
-- 0x07 -> Entering area
-- 0x08 -> Normal
-- 0x09 -> Cannot move
-- 0x0B -> Dying
-- 0x0C -> Palette cycling, can't move
function get_player_state()
    return memory.readbyte(0x000e)
end

-- Return a boolean determining if Mario is in the dying animation
function is_dying()
    return get_player_state() == 0x0b or get_y_viewport() > 1
end

-- Return a boolean determining if Mario is in the dead state
function is_dead()
    return get_player_state() == 0x06
end

-- Return 1 if the game has ended or a 0 if it has not
function is_game_over()
    return get_life() == 0xff
end

-- a table of player_state values indicating that Mario is occupied
local occupied = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x07}
-- Return boolean determining if Mario is occupied by in-game garbage
function is_occupied()
    local is_occupied = false
    local player_state = get_player_state()
    -- iterate over the values in the occupied table
    for i, state_code in ipairs(occupied) do
        is_occupied = is_occupied or player_state == state_code
    end
    return is_occupied
end

-- Hacks

-- Force the pre-level timer to 0 to skip the unnecessary frames during a
-- death transition
function runout_prelevel_timer()
    memory.writebyte(0x07A0, 0)
end

-- Skip the change area animations by checking for the timers sentinel values
-- and running them out
function skip_change_area()
    local change_area_timer = memory.readbyte(0x06DE)
    if change_area_timer > 1 and change_area_timer < 255 then
        memory.writebyte(0x06DE, 1)
        emu.frameadvance()
    end
end

-- Skip occupied states by running out a timer and skipping frames
function skip_occupied_states()
    while is_occupied() do
        runout_prelevel_timer()
        emu.frameadvance()
    end
end

-- Write the value to memory indicating that Mario has died to skip a dying
-- animation.
function kill_mario()
    memory.writebyte(0x000e, 0x06)
end

-- Rewards

-- Return the reward for moving forward on the x-axis
function get_x_reward()
    local next_x_pos = get_x_position()
    local _reward = next_x_pos - x_pos
    x_pos = next_x_pos
    return _reward
end

-- Return the penalty for staying alive. i.e. the reward stream designed
-- to convince the agent to be fast
function get_time_penalty()
    local next_time = get_time()
    local _reward = next_time - time
    time = next_time
    return _reward
end

-- Return a penalty for
function get_death_penalty()
    if is_dying() or is_dead() then
        return -100
    end
    return 0
end

-- Return the cumulative reward at the current state
function get_reward()
    return get_x_reward() + get_time_penalty() + get_death_penalty()
end

-- Press and release the start button to skip past the start/demo screen
function skip_start_screen()
    -- Press start until the game starts
    while get_time() >= time do
        time = get_time()
        -- press and release the start button
        nes_press_buttons('S')
        emu.frameadvance()
        nes_press_buttons('')
        runout_prelevel_timer()
        emu.frameadvance()
    end
end

local function before_process_command()
  skip_change_area()
  skip_occupied_states()
end

local function after_process_command()
  if is_dying() then
    kill_mario()
    emu.frameadvance()
  end
end

local function after_reset()
  x_pos = get_x_position()
  time = get_time()
end

skip_start_screen()
nes_callback.before_process_command = before_process_command
nes_callback.after_process_command = after_process_command
nes_callback.get_reward = get_reward
nes_callback.after_reset = after_reset
nes_loop();
