local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")

local L = Theme.LAYOUT

local function build(nativeChrome, phoneLayout)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return ChromeBuilder.Build(factory, parent, { width = 360, height = 640 }, { useNativeChrome = nativeChrome, phoneLayout = phoneLayout })
end

local function leftOffset(button)
  return select(4, button:GetPoint())
end

local function assertCornerSlot(chrome, label)
  local slot = chrome.iconSlot
  assert(slot ~= nil, label .. ": has an icon spot")
  assert(slot.width == L.PHONE_ICON_SLOT_SIZE, label .. ": sized for the icon")
  local point, relativeTo, relativePoint, x, y = slot:GetPoint()
  assert(point == "CENTER" and relativeTo == chrome.frame and relativePoint == "TOPLEFT", label .. ": on the window's corner")
  assert(x == L.PHONE_ICON_SLOT_X and y == L.PHONE_ICON_SLOT_Y, label .. ": at the shared spot")
end

return function()
  -- test_custom_chrome_has_a_corner_icon_spot
  do
    Hud.Configure("off")
    assertCornerSlot(build(false, true), "custom")
  end

  -- test_classic_hud_has_a_corner_icon_spot
  do
    Hud.Configure("classic")
    assertCornerSlot(build(true, true), "classic")
    Hud.Configure("off")
  end

  -- test_retail_hud_uses_its_portrait_as_the_icon_spot
  RetailHud.With(function()
    local chrome = build(true, true)
    assert(chrome.iconSlot == chrome.frame.PortraitContainer.portrait, "the portrait is the spot")
  end)

  -- test_custom_title_buttons_clear_the_spot
  do
    Hud.Configure("off")
    local classic = build(false, false)
    local phone = build(false, true)
    local shift = leftOffset(phone.newConversationButton) - leftOffset(classic.newConversationButton)
    assert(shift == L.PHONE_ICON_SLOT_CLEARANCE, "custom: moved by the clearance, got " .. tostring(shift))
  end

  -- test_classic_hud_title_buttons_clear_the_spot
  do
    Hud.Configure("classic")
    local classic = build(true, false)
    local phone = build(true, true)
    Hud.Configure("off")
    local shift = leftOffset(phone.newConversationButton) - leftOffset(classic.newConversationButton)
    assert(shift == L.PHONE_ICON_SLOT_CLEARANCE, "classic: moved by the clearance, got " .. tostring(shift))
  end

  -- test_spot_clears_the_content_below_the_title_bar
  do
    local bottom = -L.PHONE_ICON_SLOT_Y + L.PHONE_ICON_SLOT_SIZE / 2
    assert(bottom <= L.TOP_BAR_HEIGHT + L.CONTACT_SEARCH_MARGIN, "the icon stops above the search box, got " .. bottom)
    local right = L.PHONE_ICON_SLOT_X + L.PHONE_ICON_SLOT_SIZE / 2
    assert(right <= L.PHONE_ICON_SLOT_CLEARANCE + L.TITLE_BAR_INSET_X, "and left of the title buttons, got " .. right)
  end

  -- test_classic_window_has_no_icon_spot
  do
    Hud.Configure("off")
    assert(build(false, false).iconSlot == nil, "nothing rides the classic window")
  end
end
