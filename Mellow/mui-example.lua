local mui = require 'mui'
local computer = require 'computer'
local component = require 'component'
local note = require 'note'
local gpu = component.gpu



-- Fonts
local fourBet = mui.loadBet('/home/4.bet', 4, 4, '0123456789abcdefghijklmnopqrstuvwxyz/:')



-- Images
local imagePaLoop = [[
┌────┐                          ┌────┐
├─┬──│──────────────────────────│──┬─┤
│ │  │   ►                 ►    │  │ │
└────┘                          └────┘
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
  │                                │
┌────┐                          ┌────┐
│ │  │   ◄                 ◄    │  │ │
├─┴──│──────────────────────────│──┴─┤
└────┘                          └────┘
]]

local imageEmitters = [[
┌─────────┐
│ %   >───│
│ %       │
└───────┬─┘
        │
        │
        │
        │
        │
        │
        │
        │
        │
        │
        │
        │
        │
┌───────┴─┐
│    /    │
│   {  ~  │
│   >┼<───│
│  ~  }   │
│    /    │
└─────────┘
]]



-- PA bits
-- This used to be a set of component.proxy() initialisers,
-- but have been stubbed out so the program can function as an example
local sendGold
local returnGold

local sendNbti
local returnNbti

local returnBosco

local limit = {
  gold = {
    lower = 0,
    upper = 2200,
  },
  nbti = {
    lower = 1500,
    upper = 8400,
  },
  bosco = {
    lower = 7500,
    upper = 15000,
  },
}

local targets = {
  { name = 'antimatter', momentum = 300 },
  { name = 'antischrab', momentum = 400 },
  { name = 'muon', momentum = 2500 },
  { name = 'tachyon', momentum = 5000 },
  { name = 'higgs', momentum = 6500 },
  { name = 'dark', momentum = 10000 },
  { name = 'strange', momentum = 12500 },
  { name = 'spark', momentum = 12500 },
}

function setTarget(momentum)
  momentum = tonumber(momentum)
  if momentum == nil or type(momentum) ~= "number" or momentum <= 0 then
    print('please enter a valid momentum')
    return
  end

  if momentum > limit.bosco.upper then
    print('momentum too high for accelerator')
    return
  end

  -- stubbed out thresholds
  sendGold = math.min(momentum + 100, limit.gold.upper)
  returnGold = math.min(momentum, limit.gold.upper)

  sendNbti = math.min(momentum + 100, limit.nbti.upper)
  returnNbti = math.min(momentum, limit.nbti.upper)

  returnBosco = math.min(momentum, limit.bosco.upper)
end



local images = {}
local lastBtn


-- MUI start!
local events = {

  -- build out our UI elements
  init = function ()
    local imageX = 18
    local imageY = 6

    images.emitters = mui.addImage(imageX, imageY, imageEmitters)
    images.loopGold = mui.addImage(imageX + 11, imageY, imagePaLoop)
    images.loopNbti = mui.addImage(imageX + 11 + 38, imageY, imagePaLoop)
    images.loopBosco = mui.addImage(imageX + 11 + 38 + 38, imageY, imagePaLoop)

    mui.addImage(130, 1, fourBet:from('pac/ui'))

    images.momentum = mui.addImage(3, 33, fourBet:from('momentum: n/a'))
    images.particle = mui.addImage(110, 33, '', 0x00FFFF)

    mui.addHBar(37)

    local btnWidth = 16
    local btnHeight = 10
    local btnY = 40

    for i, target in ipairs(targets) do
      local x = i * (btnWidth + 2) - btnWidth + 1
      local textX = (btnWidth - #target.name) // 2

      mui.addLabel(x + textX, btnY - 1, target.name)
      mui.addBtn(x, btnY, btnWidth, btnHeight, 0x00FF00, 0x00AA00, function (btn)
        setTarget(target.momentum)

        images.particle.lines = fourBet:from(target.name)
        images.particle.x = 160 - #target.name * 5

        if lastBtn then
          lastBtn.color.default = 0x00FF00
        end
        lastBtn = btn

        btn.color.default = 0x00FFFF

        note.play('A5', 0)
      end)
    end

    -- quit
    mui.addLabel(153, btnY - 1, 'QUIT')
    mui.addBtn(151, btnY, 8, btnHeight, 0xFF0000, 0xFF0000, mui.exit)
  end,



  -- On all presses do some global updates
  touch = function (x, y)
    images.loopNbti.color = 0xFFFFFF
    images.loopBosco.color = 0xFFFFFF

    if sendGold ~= returnGold then
      images.loopNbti.color = 0xFF0000
    end

    if sendNbti ~= returnNbti then
      images.loopBosco.color = 0xFF0000
    end

    images.momentum.lines = fourBet:from('momentum: ' .. returnBosco)
  end,


  -- on shutdown,
  exit = function ()
    note.play('A4')

    -- Kiosk mode, immediately restart into the application
    if not component.isAvailable('keyboard') then
      computer.shutdown(true)
    end
  end

}

mui.runLoop(events)