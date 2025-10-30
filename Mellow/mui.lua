--[[
=======================================

  MUI BIEN!

  A lib for generating pretty OpenOS GUIs rapidly.


  API REFERENCE:

    api.runLoop(events)
  Starts the main event loop, automatically handles interrupts and touch events for most objects
  * events [object]   - a combination of `event.pull` events + our own custom events for drawing and init
    added events include:
    * draw - called after every action is performed, used for drawing
    * init - called just before drawing for the first time and entering the main loop
    * exit - called while the program is closing, whether by interrupt or `api.exit()`



    api.exit()
  Quits the program gracefully





    api.addLabel(x, y, text, color)
  Add a label to the screen
  * x [integer]         - the X position of the label
  * y [integer]         - the Y position of the label
  * text [string]       - the text that the label should show
  * color [color]       - the color of the text
  ! RETURNS [label]     - the object created by this function, allowing for modification





    api.addBtn(x, y, w, h, defaultColor, pressColor, callback)
  Add a button to the screen
  * x [integer]         - the X position of the button
  * y [integer]         - the Y position of the button
  * w [integer]         - the width of the button
  * h [integer]         - the height of the button
  * defaultolor [color] - the color of the button
  * pressColor [color]  - the color of the button when pressed
  * callback [function] - the function to call when the button is pressed
  ! RETURNS [button]    - the object created by this function, allowing for modification





    api.addImage(x, y, content, color)
  Add an image to the screen
  * x [integer]             - the X position of the image
  * y [integer]             - the Y position of the image
  * content [string|array]  - either an array of strings, or a newline separated single string
  * color [color]           - the color of the image
  ! RETURNS [image]         - the object created by this function, allowing for modification

      EXAMPLE:
    local image = [[
    ┌─────────┐
    │ %   >───│
    │ %   hi! │
    └───────┬─┘
    ]]                                                                            --[[ ignore me I'm reopening the comment

    mui.addImage(4, 4, image)

      -- OR --

    local bet = api.loadBet('/home/big.bet')
    mui.addImage(4, 4, bet:from('hi'))



    image:setContent(content)
  Sets the image's content to a new value
  * content [string|array]  - either an array of strings, or a newline separated single string





    api.addHBar(y, color)
  Adds a horizontal bar to the screen
  * y [integer]             - the Y position of the bar
  * color [color]           - the color of the bar





    api.loadBet(filename, width, height, letterMap)
  Load an alphabet from a file, make sure each character is separated by an empty newline,
  characters must be fixed width and height!
  * filename [string]   - location of the character map on disk
  * width [integer]     - width of the characters
  * height [integer]    - height of the characters
  * letterMap [string]  - the letters in the file, in order!
  ! RETURNS [bet]       - a table of all the letters, each letter being an array of strings,
                          can be indexed like `object.a` to get the lines for letter "a"



    bet:from(inputText)
  Turns an input string into an array of lines, ready for use in an `Image`
  * inputText [string]  - The string you'd like to turn into a big font
  ! RETURNS [array]     - an array of strings


  MUCHA SUERTE!

-- =======================================
]]


local term = require 'term'
local event = require 'event'
local text = require 'text'
local component = require 'component'
local gpu = component.gpu

local api = {}

local running = true
local pending = false
local elements = {}



-- ALPHABET
local function betFrom(bet, inputText)
  local lines = {}

  for c in inputText:gmatch('.') do
    for i, v in ipairs(bet[c]) do
      if not lines[i] then
        lines[i] = ''
      else
        lines[i] = lines[i] .. ' '
      end

      lines[i] = lines[i] .. v
    end
  end

  return lines
end

function api.loadBet(filename, width, height, letterMap)
  local bet = {}

  local file = io.open(filename)

  local index = 1
  local letterLines

  for line in file:lines() do
    if line:match('^%s*$') then
      if letterLines then
        bet[letterMap:sub(index, index)] = letterLines
        index = index + 1
      end

      letterLines = {}
    else
      if not letterLines then letterLines = {} end
      table.insert(letterLines, text.padRight(line, width))
    end
  end

  if #letterLines > 0 then
    bet[letterMap:sub(index, index)] = letterLines
  end

  local space = {}
  for y = 1, height do
    space[y] = string.rep(' ', width)
  end

  bet[' '] = space


  bet.width = width
  bet.height = height
  bet.from = betFrom

  return bet
end
-- /ALPHABET



-- BUTTON
local function btnPress(btn, x, y)
  if x < btn.x or x > btn.x + btn.w or y < btn.y or y > btn.y + btn.h then return end

  btn.callback(btn)
  btn.state = true

  pending = true
end

local function btnDraw(btn)
  if btn.last then
    gpu.setBackground(0x000000)
    gpu.fill(btn.last.x, btn.last.y, btn.last.w, btn.last.h, ' ')
  end

  gpu.setBackground(btn.state and btn.color.pressed or btn.color.default)
  gpu.fill(btn.x, btn.y, btn.w, btn.h, ' ')
  gpu.setBackground(0x000000)

  btn.last = {
    x = btn.x,
    y = btn.y,
    w = btn.w,
    h = btn.h,
  }
end

function api.addBtn(x, y, w, h, defaultColor, pressColor, callback)
  local btn = {
    x = x,
    y = y,
    w = w,
    h = h,
    color = {
        default = defaultColor,
        pressed = pressColor,
    },
    state = false,
    callback = callback,
    press = btnPress,
    draw = btnDraw,
    last = nil,
  }

  table.insert(elements, btn)
  return btn
end
-- /BUTTON



-- LABEL
local function labelDraw(label)
  if label.last then
    gpu.fill(label.last.x, label.last.y, label.last.w, 1, ' ')
  end

  gpu.setForeground(label.color)
  gpu.set(label.x, label.y, label.text)

  label.last = {
    x = label.x,
    y = label.y,
    w = #label.text,
  }
end

function api.addLabel(x, y, text, color)
  local label = {
    x = x,
    y = y,
    text = text,
    color = color or 0xFFFFFF,
    draw = labelDraw,
    last = nil,
  }

  table.insert(elements, label)
  return label
end
-- /LABEL



-- IMAGE
function imageDraw(image)
  gpu.setForeground(image.color)

  if image.lastX and image.lastY and image.lastWidth and image.lastHeight then
    gpu.fill(image.lastX, image.lastY, image.lastWidth, image.lastHeight, ' ')
  end

  local width = 0
  for i, line in ipairs(image.lines) do
    gpu.set(image.x, image.y + i - 1, line)
    width = math.max(width, #line)
  end

  image.lastX = image.x
  image.lastY = image.y
  image.lastWidth = width
  image.lastHeight = #image.lines
end

function imageSetContent(image, content)
  local lines = {}
  if type(content) == 'string' then
    for line in content:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
  else
    lines = content
  end

  image.lines = lines
end

function api.addImage(x, y, content, color)
  local image = {
    x = x,
    y = y,
    color = color or 0xFFFFFF,
    setContent = imageSetContent,
    draw = imageDraw,
    lastWidth = 0,
  }

  image:setContent(content)

  table.insert(elements, image)
  return image
end
-- /IMAGE



-- HBAR
local function hbarDraw(hbar)
  if hbar.last then
    gpu.fill(3, hbar.last.y, 156, 1, ' ')
  end

  gpu.setForeground(hbar.color)
  gpu.fill(3, hbar.y, 156, 1, '─')

  hbar.last = {
    y = hbar.y,
  }
end

function api.addHBar(y, color)
  local hbar = {
    y = y,
    color = color or 0xFFFFFF,
    draw = hbarDraw,
  }

  table.insert(elements, hbar)
  return hbar
end
-- /HBAR



-- LOOP
function api.runLoop(events)
  local inInterrupt = events.interrupted
  local inTouch = events.touch
  local inDraw = events.draw

  events.interrupted = function ()
    running = false

    if inInterrupt then inInterrupt() end
  end

  events.touch = function (x, y)
    for _, e in ipairs(elements) do
      if e.press then e:press(x, y) end
    end

    if inTouch then inTouch(x, y) end
  end

  events.draw = function ()
    for i, e in ipairs(elements) do
      e:draw()
    end

    if inDraw then inDraw() end
  end

  if events.init then
    events.init()
  end

  term.clear()
  events.draw()

  while running do
    -- if pending a redraw, update after a small wait
    local id, _, x, y = event.pullFiltered(pending and 0.1 or nil, function (id) return events[id] ~= nil end)

    if pending then
      for i, e in ipairs(elements) do
        if e.state then e.state = false end
      end

      pending = false
    end

    local performEvent = events[id]
    if performEvent then performEvent(x, y) end

    events.draw()
  end

  if events.exit then
    events.exit()
  end

  term.clear()
end
-- /LOOP



-- DIE
function api.exit()
  running = false
end
-- /~ATH



return api