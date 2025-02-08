local M = {}
local reset_subscription, stop_subscription

M.nextFrame = 0
M.gameState = 0
M.activeState = false
M.previousState = false
M.debugState = false

local MEMORY_ADDR = {}
-- gets set to 0x0 during gameplay
-- MEMORY_ADDR.GAME_ACTIVE = 0x25E0
MEMORY_ADDR.GAME_ACTIVE = 0x25E0 + 4
-- set to an integer representing club number 1-13
MEMORY_ADDR.CLUB_SELECT = 0x2480

-- Source: https://www.trackman.com/blog/golf/introducing-updated-tour-averages
-- we plus or minus a few yards to the PGA averages for each club as the max you can acheive
local CLUBS = {};
CLUBS[1] = { name = 'D', max_mph = 200, distance = 300, code = 0 }
CLUBS[2] = { name = '3W', max_mph = 170, distance = 275, code = 1 }
CLUBS[3] = { name = '5W', max_mph = 160, distance = 250, code = 2 }
CLUBS[4] = { name = '2I', max_mph = 120, distance = 225, code = 3 }
CLUBS[5] = { name = '3I', max_mph = 100, distance = 200, code = 4 }
CLUBS[6] = { name = '4I', max_mph = 100, distance = 180, code = 5 }
CLUBS[7] = { name = '5I', max_mph = 100, distance = 160, code = 6 }
CLUBS[8] = { name = '6I', max_mph = 100, distance = 150, code = 7 }
CLUBS[9] = { name = '7I', max_mph = 95, distance = 140, code = 8 }
CLUBS[10] = { name = '8I', max_mph = 95, distance = 125, code = 9 }
CLUBS[11] = { name = '9I', max_mph = 90, distance = 100, code = 10 }
CLUBS[12] = { name = 'W', max_mph = 80, distance = 80, code = 11 }
CLUBS[13] = { name = 'SW', max_mph = 80, distance = 60, code = 12 }
CLUBS[14] = { name = 'P', max_mph = 40, distance = 4, code = 13 }
CLUBS[15] = { name = '?', max_mph = 40, distance = 4, code = 99 }

function M.dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

function utf8_from(t)
  local bytearr = {}
  for _, v in ipairs(t) do
    local utf8byte = v < 0 and (0xff + v + 1) or v
    table.insert(bytearr, string.char(utf8byte))
  end
  return table.concat(bytearr)
end

function bcd2dec(mem, address)
  bytes = {}
  for byte_address = address, address + 31 do
    byte = mem:read_u8(byte_address)
    bytes[#bytes + 1] = byte & 0x0F
    bytes[#bytes + 1] = (byte & 0xF0) >> 4
  end
  return bytes;
  -- total = 0
  -- for index, value in ipairs(bytes) do
  --   total = total + (value * math.floor(10 ^ (index - 1)))
  -- end

  -- return total
end

function M.getYardage()
  local mem = manager.machine.devices[":maincpu"].spaces["program"]
  local memoryBlock = mem:read_i64(0x1960)
  local bytes = {}
  for i = 0, 2 do
    local byte = (memoryBlock >> (i * 8)) & 0xFF
    if byte then
      table.insert(bytes, string.char(byte))
    end
  end
  local yards = string.reverse(string.format("%s", table.concat(bytes)))
  -- io.stderr:write(string.format('{ "yards": %s }\n', yards))
  return yards
end

function ternary(cond, T, F)
  if cond then return T else return F end
end

function M.getGameState()
  -- local address = 0x1950
  local mem = manager.machine.devices[":maincpu"].spaces["program"]

  local activeBlock = mem:read_u32(MEMORY_ADDR.GAME_ACTIVE)
  if M.lastBlock ~= activeBlock then
    print(string.format('activeBlock 0x%x ', activeBlock))
    M.lastBlock = activeBlock
  end

  local isReady = mem:read_u8(MEMORY_ADDR.GAME_ACTIVE) == 0xff
  local isActive = mem:read_u8(MEMORY_ADDR.GAME_ACTIVE) ~= 0xff

  if M.gameState == 0 and isReady then
    M.gameState = 1
  end
  if M.gameState == 1 and isActive then
    M.gameState = 2
  end

  local stateBlock = mem:read_u8(MEMORY_ADDR.CLUB_SELECT + 5)
  -- -- print('stateBlock first: ' .. string.format("0x%x ", stateBlock))

  -- local bytes = {}
  -- for i = 0, 3 do
  --   local byte = (stateBlock >> (i * 8)) & 0xFF
  --   if byte then
  --     -- print(string.format("\n%d %x ", i, byte))
  --     table.insert(bytes, 1, byte)
  --   end
  -- end

  local bytes = {}
  for byte_address = MEMORY_ADDR.CLUB_SELECT, MEMORY_ADDR.CLUB_SELECT + 7 do
    byte = mem:read_u8(byte_address)
    -- print(byte)
    -- local byte = (memoryBlock >> (i * 8)) & 0xFF
    -- bytes[#bytes + 1] = byte & 0xFF
    -- bytes[#bytes + 1] = (byte & 0xF0) >> 4
    if byte ~= nil then
      table.insert(bytes, string.format("%x", byte))
    end
  end
  -- print(string.format("0x%s", table.concat(bytes)))
  total = 0
  -- for index, value in ipairs(bytes) do
  --   total = total + (value * math.floor(10 ^ (index - 1)))
  -- end
  -- print(total)
  -- print('bytes: ' .. string.format('0x%x', table.concat(bytes)))
  -- print('state: ' .. string.format('0x%x', bytes[2]))
  -- print('club: ' .. string.format('0x%x', bytes[4]))
  -- print('club D: ' .. string.format('0x%x', CLUBS[1].code))


  local selectedClub = CLUBS[15]
  for _, club in ipairs(CLUBS) do
    if club.code == stateBlock then
      selectedClub = club
    end
  end

  local state = ternary(M.gameState > 1, 'active', 'inactive')
  return {
    active = M.gameState > 1,
    club = selectedClub,
    state = state,
  }
end

function M.gameActivated()
  M.activeState = true
  print("Controls have been activated")
  -- we only need control of the trackball (arrow keys) during actual gameplay
  local ioport = manager.machine.ioport
  local inx = ioport.ports[":TRACKX1"]
  local iny = ioport.ports[":TRACKY1"]
  -- we set to our initial center point of 128, half the value of the full 0-255 range of x axis
  inx.fields["Trackball X"]:set_value(128)
  iny.fields["Trackball Y"]:set_value(0)
  emu.wait_next_frame()
end

function M.gameDeactivated()
  M.activeState = false
  -- allows trackball (arrow keys) to be used when not in gameplay
  print("Controls have been deactivated")
  local ioport = manager.machine.ioport
  local inx = ioport.ports[":TRACKX1"]
  local iny = ioport.ports[":TRACKY1"]
  inx.fields["Trackball X"]:clear_value()
  iny.fields["Trackball Y"]:clear_value()
  emu.wait_next_frame()
end

function M.updateMem()
  s = manager.machine.screens[':screen']
  local state = M.getGameState()
  -- k = manager.machine.uiinput

  -- local mem = manager.machine.devices[":maincpu"].spaces["program"]
  -- local byte = mem:read_i32(0x1950)



  -- -- read yardage from memory
  -- local yardarge = mem:read_i64(0x1960)
  -- local bytes = {}
  -- for i = 0, 2 do
  --   local byte = (yardarge >> (i * 8)) & 0xFF
  --   if byte then
  --     table.insert(bytes, string.char(byte))
  --   end
  -- end


  -- local yards = string.reverse(string.format("%s", table.concat(bytes)))

  -- print('prv: ' .. ternary(M.previousState, 'y', 'n') .. ' active: ' .. ternary(state.active, 'y', 'n'))
  if M.previousState == false and state.active == true then
    print("Activate!!!")
    M.gameActivated()
  end
  M.previousState = state.active

  -- if M.activeState == true and state.state.active == false then
  --   print("Deactivate!!!")
  --   M.gameDeactivated()
  -- end

  if M.debugState then
    -- s:draw_text(2, 2, '1 = START |') -- (x0, y0, msg)
    -- print(state.club)
    -- s:draw_text(5, 15, 'club: ' .. string.format('%d', state.club)) -- (x0, y0, msg)
    s:draw_text(2, 2, 'CLUB: ' .. state.club.name)                                -- (x0, y0, msg)
    s:draw_text(35, 2, 'STATE: ' .. ternary(M.activeState, 'active', 'inactive')) -- (x0, y0, msg)
    -- s:draw_text(5, 33, 'state: ' .. state.state)                                  -- (x0, y0, msg)
    -- local yards = M.getYardage()
    -- print(yards)
    -- s:draw_text(100, 2, 'key: ' .. ternary(keyPressed, 'YES', 'NO')) -- (x0, y0, msg)
    s:draw_box(0, 0, 90, 12, 0xcc828f8f, 0) -- (x0, y0, x1, y1, line-color, fill-color)
  end

  local keyPressedX = manager.machine.input:code_pressed_once(manager.machine.input:code_from_token("KEYCODE_X"))
  if keyPressedX then
    print("Manually toggling trackball control...")
    if M.activeState then
      M.gameDeactivated()
    else
      M.gameActivated()
    end
  end

  local keyPressedD = manager.machine.input:code_pressed_once(manager.machine.input:code_from_token("KEYCODE_D"))
  if keyPressedD then
    if M.debugState then
      M.debugState = false
    else
      M.debugState = true
    end
  end

  M.nextFrame = M.nextFrame + 1
end

function M.pressCoin()
  local ioport = manager.machine.ioport
  local in1 = ioport.ports[":P1"]
  -- local coin1 = { in1 = in1, field = in1.fields["Coin 1"] }

  emu.wait_next_frame()
  in1.fields["Coin 1"]:set_value(1)
  emu.wait_next_frame()
  in1.fields["Coin 1"]:set_value(0)
end

function M.pressStart()
  local ioport   = manager.machine.ioport
  local in1      = ioport.ports[":P1"]
  local startBtn = { in1 = in1, field = in1.fields["1 Player Start"] }

  in1.fields["1 Player Start"]:set_value(0x80)
  emu.wait_next_frame()
  -- in1.fields["1 Player Start"]:set_value(1)
  emu.wait_next_frame()
  in1.fields["1 Player Start"]:set_value(0)
  emu.wait_next_frame()
end

function M.initialize()
  -- set initial x trackball to our center point
  -- we do this before the trackball is active for the shot
  -- disable for debugging
  -- local ioport = manager.machine.ioport
  -- local inx = ioport.ports[":TRACKX1"]
  -- inx.fields["Trackball X"]:set_value(128)
  -- emu.wait_next_frame()
end

function M.pressLeftRight(direction)
  -- set initial x trackball to our center point
  -- we do this before the trackball is active for the shot
  local ioport = manager.machine.ioport
  local inx = ioport.ports[":TRACKX1"]
  local distance = 40 * direction;
  print("distance " .. distance)

  -- 10 frames
  for i = 0, 10, 1 do
    local percent = i / 10
    local val = 128 + (distance * percent)
    print("distance " .. distance .. " val: " .. val)
    inx.fields["Trackball X"]:set_value(val)
    emu.wait_next_frame()
  end
end

function M.aimLeftRight(direction)
  local ioport = manager.machine.ioport
  local in1 = ioport.ports[":P1"]
  -- local coin1 = { in1 = in1, field = in1.fields["Coin 1"] }
  if direction > 0 then
    in1.fields["P1 Face Right"]:set_value(1)
    emu.wait_next_frame()
    in1.fields["P1 Face Right"]:set_value(0)
    emu.wait_next_frame()
  else
    in1.fields["P1 Face Left"]:set_value(1)
    emu.wait_next_frame()
    in1.fields["P1 Face Left"]:set_value(0)
    emu.wait_next_frame()
  end
end

function M.autostart()
  local ioport = manager.machine.ioport
  local iny    = ioport.ports[":TRACKY1"]
  local tracky = { iny = iny, field = iny.fields["Trackball Y"] }

  -- start game
  M.pressStart()
  emu.wait(0.2)

  -- insert coins
  M.pressCoin()
  emu.wait(0.2)
  M.pressCoin()
  emu.wait(0.2)

  -- start game
  M.pressStart()
  emu.wait(0.5)

  -- scroll to 1-player
  local moveIncrement = 8
  local moveTo = 50

  for i = 0, moveTo, moveIncrement do
    print('set tracky ' .. i)
    tracky.field:set_value(i)
    emu.wait_next_frame()
  end
  emu.wait(1)

  -- select 1-player
  M.pressStart()
  emu.wait(2)

  -- continue
  M.pressStart()
  emu.wait(1)

  -- start course
  M.pressStart()
  emu.wait(1)
end

function percentageOfRange(min, max, percentage)
  return (((max - min) / 100) * percentage) + min
end

function clampToRange(val, min, max)
  return math.min(math.max(val, min), max);
end

function M.sendShot(ballSpeed, hla)
  local ioport = manager.machine.ioport

  local state = M.getGameState()
  local power = clampToRange(ballSpeed / state.club.max_mph, 0, 1)
  -- percentageOfRange(1, state.club.max_mph, percentage)
  local percentage = power * 100
  print("-- percentage: " .. percentage)

  print('\n\n--- Sending Shot ---\n ballSpeed: ' .. ballSpeed .. ' power: ' .. power .. ' hla: ' .. hla .. '\n\n')
  local inx    = ioport.ports[":TRACKX1"]
  local iny    = ioport.ports[":TRACKY1"]
  local trackx = { inx = inx, field = inx.fields["Trackball X"] }
  local tracky = { iny = iny, field = iny.fields["Trackball Y"] }

  print('\n\n')
  -- -- M.xis_analog = M.trackx.field.is_analog()
  print('trackx.minvalue' .. trackx.field.minvalue)
  print('trackx.maxvalue' .. trackx.field.maxvalue)
  print('trackx.defvalue' .. trackx.field.defvalue)
  print(M.dump(trackx.field.settings))

  if trackx.field.analog_wraps then
    print('trackx.analog_wraps = YES')
  else
    print('trackx.analog_wraps = NO')
  end
  if trackx.field.analog_reset then
    print('trackx.analog_reset = YES')
  else
    print('trackx.analog_reset = NO')
  end
  -- if M.trackx.field.analog_invert then
  --   print('trackx.analog_invert = YES')
  -- else
  --   print('trackx.analog_invert = NO')
  -- end
  -- if M.trackx.field.analog_reverse then
  --   print('trackx.analog_reverse = YES')
  -- else
  --   print('trackx.analog_invert = NO')
  -- end


  -- trackx.field:clear_value()
  -- tracky.field:clear_value()
  -- emu.wait_next_frame()
  -- trackx.field:set_value(trackx.field.maxvalue / 2)
  -- M.trackx.field:set_value(0)
  -- emu.wait_next_frame()
  -- local swingSpeedMin = 1
  -- local swingSpeedMax = 30
  -- local swingSpeed = (((swingSpeedMax - swingSpeedMin) / 100) * percentage ) + swingSpeedMin
  -- how many units of movement per frame
  local swingSpeed = percentageOfRange(1, 30, percentage)
  -- range of accetable golf swing?
  -- local swingRangeMin = 128
  -- local swingRangeMax = 255
  -- local swingRange = (((swingRangeMax - swingRangeMin) / 100) * percentage ) + swingRangeMin

  -- how many total frames of movement
  local swingRange = percentageOfRange(128, 255, percentage)
  print("swingSpeed: " .. swingSpeed)
  print("swingRange: " .. swingRange)

  local xcenter = 128

  -- local xpos = 128
  -- upswing
  local xoffset = xcenter * (hla / xcenter)
  local diff = xoffset - xcenter

  for i = 0, swingRange, swingSpeed do
    -- percent from 0% - 100%
    local percentComplete = i / (swingRange - 1)
    local downswingAngle = 128 - (diff * percentComplete);
    print('upswingAngle: ' .. downswingAngle .. ' percent: ' .. percentComplete)
    -- -- the handle for the upswing is reversed from the launch angle
    -- local reverseAngle
    tracky.field:set_value(i)
    trackx.field:set_value(downswingAngle)
    emu.wait_next_frame()

    -- print('trackx.live' .. trackx.field.live)
  end

  -- pause at the top of the swing for a couple frames
  emu.wait_next_frame()
  emu.wait_next_frame()

  -- downswing
  -- question: should the downswing speed always be faster?
  -- right now I add 30% speed to the up to ensure shots happen
  for i = swingRange, 0, -swingSpeed do
    -- local animProgress = (totalFrames - frame) / totalFrames;
    -- local percentComplete = (swingRange - i) / swingRange;
    -- percent from 90% - 0%
    local percentComplete = i / (swingRange - 1)
    -- local downswingAngle = hla - 128
    -- local downswingAngle = (diff * percentComplete) + 128;
    local downswingAngle = 128 - (diff * percentComplete);
    print('downswingAngle: ' .. downswingAngle .. ' percent: ' .. percentComplete)
    tracky.field:set_value(i)
    trackx.field:set_value(downswingAngle)
    emu.wait_next_frame()
  end

  -- wait for the shot to finish, then reset the center point
  emu.wait(1)
  trackx.field:set_value(128)

  -- M.tracky.field:set_value(255)
  -- emu.wait_next_frame()
  -- M.tracky.field:set_value(0)
  -- emu.wait_next_frame()
end

function M.startplugin()
  -- M.ioport = manager.machine.ioport
  print("Goldenpro plugin is starting...")


  reset_subscription = emu.add_machine_reset_notifier(
    function()
      emu.print_info("Starting " .. emu.gamename())
      -- M.initialize()
      emu.register_frame_done(M.updateMem, "frame")
    end)

  stop_subscription = emu.add_machine_stop_notifier(
    function()
      emu.print_info("Exiting " .. emu.gamename())
    end)
end

return M
