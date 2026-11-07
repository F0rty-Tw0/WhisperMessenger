local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local L = Theme.LAYOUT
local HUD_GAP = 2

-- size: the title bar's height (the custom bar; the HUD title strip its
-- buttons fill). gap: the look's gap between title controls.
local LOOKS = {
  { name = "custom", style = "off", native = false, size = L.TOP_BAR_HEIGHT, gap = L.TITLE_BUTTON_GAP },
  { name = "classic", style = "classic", native = true, size = L.CHROME_BUTTON_SIZE, gap = HUD_GAP },
  { name = "retail", style = "retail", native = true, size = L.CHROME_BUTTON_SIZE, gap = HUD_GAP },
}

local function build(look, phoneLayout)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 360, height = 640 }, { useNativeChrome = look.native, phoneLayout = phoneLayout })
end

local function withLook(look, body)
  if look.style == "retail" then
    RetailHud.With(body)
    return
  end
  Hud.Configure(look.style)
  local ok, err = pcall(body)
  Hud.Configure("off")
  assert(ok, err)
end

-- Every look, compact and regular.
local function eachCase(run)
  for _, look in ipairs(LOOKS) do
    for _, phone in ipairs({ true, false }) do
      withLook(look, function()
        local chrome = build(look, phone)
        run(chrome, look, (look.name .. (phone and " compact" or " regular")), phone)
      end)
    end
  end
end

local function anchor(region)
  local _, relativeTo, _, x, y = region:GetPoint()
  return relativeTo, x, y
end

-- The fake keeps every point set; the title bar has a second one on the right.
local function topLeftPoint(region)
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == "TOPLEFT" and pt[3] == "TOPLEFT" then
      return pt[2], pt[4], pt[5]
    end
  end
  error("pinned by its top-left corner")
end

-- The spot's anchor resolved to the window's top-left corner.
local function cornerOffset(chrome, region)
  local relativeTo, x, y = topLeftPoint(region)
  if relativeTo == chrome.frame then
    return x, y
  end
  local parentX, parentY = cornerOffset(chrome, relativeTo)
  return parentX + x, parentY + y
end

local function dockSquare(chrome)
  chrome.setIconSlotOccupied(true, chrome.titleIconSlot)
end

return function()
  -- test_square_spot_is_as_tall_as_the_title_bar
  eachCase(function(chrome, look, label)
    local slot = chrome.titleIconSlot
    assert(slot ~= nil and slot ~= chrome.iconSlot, label .. ": a second spot for the square")
    assert(slot:GetWidth() == look.size and slot:GetHeight() == look.size, label .. ": title-bar high, got " .. tostring(slot:GetHeight()))
    if chrome.titleBar then
      assert(slot:GetHeight() == chrome.titleBar:GetHeight(), label .. ": the custom title bar's own height")
    end
  end)

  -- test_square_spot_sits_inside_the_window
  eachCase(function(chrome, look, label)
    local slot = chrome.titleIconSlot
    if look.style == "retail" then
      -- The template's title strip starts right of the portrait, inside the frame.
      local relativeTo, x, y = anchor(slot)
      assert(relativeTo == chrome.frame.TitleContainer and x >= 0 and y == 0, label .. ": at the start of the title strip")
      return
    end
    local x, y = cornerOffset(chrome, slot)
    assert(x >= 0 and y <= 0, label .. ": no overhang past the corner, got " .. x .. "," .. y)
  end)

  -- test_square_spot_sits_left_of_the_first_title_control_without_overlap
  eachCase(function(chrome, look, label, phone)
    dockSquare(chrome)
    local slotTo, slotX = anchor(chrome.titleIconSlot)
    local first = { chrome.newConversationButton }
    if phone then
      chrome.setPhoneChatView(true)
      first = { chrome.backButton }
    end
    for _, control in ipairs(first) do
      local controlTo, controlX = anchor(control)
      assert(controlTo == slotTo, label .. ": on the same row")
      assert(controlX - slotX == look.size + look.gap, label .. ": right of the spot by the gap, got " .. tostring(controlX - slotX))
    end
  end)

  -- test_square_docked_title_controls_shift_by_the_spot_and_gap_and_come_back
  eachCase(function(chrome, look, label)
    chrome.setIconSlotOccupied(false)
    local free = select(2, anchor(chrome.newConversationButton))
    dockSquare(chrome)
    local shift = select(2, anchor(chrome.newConversationButton)) - free
    assert(shift == look.size + look.gap, label .. ": moved clear by the spot and the gap, got " .. tostring(shift))
    chrome.setIconSlotOccupied(false)
    assert(select(2, anchor(chrome.newConversationButton)) == free, label .. ": room given back")
  end)
end
