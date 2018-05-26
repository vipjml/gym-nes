-- global variables
local screen = {} -- screen pixels [x,y] = p
local pipe_out_name = nil
local pipe_out = nil -- for sending data(output e.g. screen pixels, reward) back to client
local pipe_in_name = nil
local pipe_in = nil -- for getting data(input e.g. controller status change) from client

local SEP = string.format('%c', 0xFF) -- as separator in communication protocol
local IN_SEP = '|'
gamestate = savestate.object()
local reward = 0

local COMMAND_TABLE = {
  A = "A",
  B = "B",
  U = "up",
  L = "left",
  D = "down",
  R = "right",
  S = "start",
  s = "select"
}

-- exported common functions start with nes_ prefix
-- called before each episode
local function nes_reset()
  -- load state so we don't have to instruct to skip title screen
  savestate.load(gamestate)
  if nes_callback.after_reset ~= nil then
    nes_callback.after_reset();
  end
end

-- split - Splits a string with a specific delimiter
local function split(self, delimiter)
  local results = {}
  local start = 1
  local split_start, split_end  = string.find(self, delimiter, start)
  while split_start do
    table.insert(results, string.sub(self, start, split_start - 1))
    start = split_end + 1
    split_start, split_end = string.find(self, delimiter, start)
  end
  table.insert(results, string.sub(self, start))
  return results
end

-- write_to_pipe - Write data to pipe
local function write_to_pipe(data)
  if data and pipe_out then
    pipe_out:write(data .. SEP .. "\n")
    pipe_out:flush()
  end
end

local function write_to_pipe_partial(data)
  if data and pipe_out then
    pipe_out:write(data)
  end
end

local function write_to_pipe_end()
  if pipe_out then
    pipe_out:write(SEP .. "\n")
    pipe_out:flush()
  end
end

-- called once when emulator starts
local function nes_init()
  emu.speedmode("maximum")
  -- emu.speedmode("normal")

  for x = 0, 255 do
    screen[x] = {}
    for y = 0, 223 do
      screen[x][y] = -1
    end
  end

  frame_skip = tonumber(os.getenv("frame_skip"))
  pipe_in_name = os.getenv("pipe_out_name")
  pipe_out_name = os.getenv("pipe_in_name")
  -- from emulator to client
  pipe_out, _, _ = io.open(pipe_out_name, "w")
  -- from client to emulator
  pipe_in, _, _ = io.open(pipe_in_name, "r")

  write_to_pipe("ready" .. SEP .. emu.framecount())
  savestate.save(gamestate)
end

local function nes_send_state(reward, done)
  local r, g, b, p
  -- NES only has y values in the range 8 to 231, so we need to offset y values by 8
  local offset_y = 8
  -- write the opcode for a new state
  write_to_pipe_partial("state" .. SEP)
  -- write the reward
  write_to_pipe_partial(string.format("%d", reward) .. SEP)
  -- write the done flag as an integer
  if done then
    write_to_pipe_partial(1 .. SEP)
  else
    write_to_pipe_partial(0 .. SEP)
  end
  -- write the screen pixels to the pipe one scan-line at a time
  for y = 0, 223 do
    local screen_string = ""
    for x = 0, 255 do
      r, g, b, p = emu.getscreenpixel(x, y + offset_y, true)
      -- offset p by 20 so the content can never be '\n'
      screen_string = screen_string .. string.format("%c", p+20)
    end
    write_to_pipe_partial(screen_string)
  end
  -- write the terminal command sentinel to the pipe
  write_to_pipe_end()
end

local function show_joypad_command(joypad_command)
  local button_text_y = 25;
  for k,v in pairs(joypad_command) do
    gui.text(5,button_text_y, k)
    button_text_y = button_text_y + 10
   end
end

--- private functions
-- handle one command
local function nes_handle_command()
  local line = pipe_in:read()
  local body = split(line, IN_SEP)
  local command = body[1]
  if command == 'reset' then
    nes_reset()
  elseif command == 'joypad' then
    -- joypad command
    local buttons = body[2]
    local joypad_command = {}
    for i = 1, #buttons do
      local btn = buttons:sub(i,i)
      local button = COMMAND_TABLE[buttons:sub(i,i)]
      joypad_command[button] = true
    end
	reward = 0
	for frame_i=1,frame_skip do
      show_joypad_command(joypad_command)
	  joypad.set(1, joypad_command)
      emu.frameadvance()
	  if nes_callback.get_reward ~= nil then
		reward = reward + nes_callback.get_reward();
	  end
    end
  end
end

function nes_press_buttons(buttons)
  -- Reset the global joy-pad to an empty table
  joypad_command = {}
  -- Iterate over the buttons and set each as a key in `joypad_command`
  -- with a value of 'true'
  for i = 1, #buttons do
    local button = COMMAND_TABLE[buttons:sub(i,i)]
    joypad_command[button] = true
  end
  joypad.set(1, joypad_command)
end

-- Read a range of bytes and return a number
function nes_readbyterange(address, length)
  local return_value = 0
  for offset = 0,length-1 do
    return_value = return_value * 10
    return_value = return_value + memory.readbyte(address + offset)
  end
  return return_value
end

function nes_loop()
  nes_init()
  while true do
    if nes_callback.before_process_command ~= nil then
	  nes_callback.before_process_command()
	end
    nes_handle_command()
	if nes_callback.after_process_command ~= nil then
	  nes_callback.after_process_command()
	end
	local isdone = false
    nes_send_state(reward,isdone)
  end
end

nes_callback = {before_process_command = nil,after_process_command = nil, 
get_reward = nil, after_reset = nil}