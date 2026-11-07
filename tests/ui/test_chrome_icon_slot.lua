local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local WindowBounds = require("WhisperMessenger.UI.MessengerWindow.WindowBounds")

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

  -- test_an_empty_spot_gives_its_room_back
  for _, nativeChrome in ipairs({ false, true }) do
    Hud.Configure(nativeChrome and "classic" or "off")
    local classic = build(nativeChrome, false)
    local phone = build(nativeChrome, true)
    Hud.Configure(nativeChrome and "classic" or "off")
    phone.setIconSlotOccupied(false)
    assert(leftOffset(phone.newConversationButton) == leftOffset(classic.newConversationButton), "title buttons go all the way left")
    phone.setIconSlotOccupied(true)
    local shift = leftOffset(phone.newConversationButton) - leftOffset(classic.newConversationButton)
    assert(shift == L.PHONE_ICON_SLOT_CLEARANCE, "and move clear again, got " .. tostring(shift))
    Hud.Configure("off")
  end

  -- test_spot_clears_the_content_below_the_title_bar
  do
    local bottom = -L.PHONE_ICON_SLOT_Y + L.PHONE_ICON_SLOT_SIZE / 2
    assert(bottom <= L.TOP_BAR_HEIGHT + L.CONTACT_SEARCH_MARGIN, "the icon stops above the search box, got " .. bottom)
    local right = L.PHONE_ICON_SLOT_X + L.PHONE_ICON_SLOT_SIZE / 2
    assert(right <= L.PHONE_ICON_SLOT_CLEARANCE + L.TITLE_BAR_INSET_X, "and left of the title buttons, got " .. right)
  end

  -- test_regular_window_has_a_corner_icon_spot_on_each_chrome
  do
    Hud.Configure("off")
    assertCornerSlot(build(false, false), "regular custom")
    Hud.Configure("classic")
    assertCornerSlot(build(true, false), "regular classic")
    Hud.Configure("off")
  end
  RetailHud.With(function()
    local chrome = build(true, false)
    assert(chrome.iconSlot == chrome.frame.PortraitContainer.portrait, "regular retail: the portrait is the spot")
  end)

  -- test_regular_title_buttons_move_clear_only_while_the_spot_is_taken
  for _, nativeChrome in ipairs({ false, true }) do
    Hud.Configure(nativeChrome and "classic" or "off")
    local regular = build(nativeChrome, false)
    local free = leftOffset(regular.newConversationButton)
    regular.setIconSlotOccupied(true)
    assert(leftOffset(regular.newConversationButton) - free == L.PHONE_ICON_SLOT_CLEARANCE, "regular: moved clear by the clearance")
    regular.setIconSlotOccupied(false)
    assert(leftOffset(regular.newConversationButton) == free, "regular: room given back")
    Hud.Configure("off")
  end
  RetailHud.With(function()
    local regular = build(true, false)
    local free = leftOffset(regular.newConversationButton)
    regular.setIconSlotOccupied(true)
    assert(leftOffset(regular.newConversationButton) == free, "regular retail: the title bar already clears the portrait")
  end)

  -- test_regular_left_cluster_clears_the_centred_title_at_minimum_width
  for _, nativeChrome in ipairs({ false, true }) do
    Hud.Configure(nativeChrome and "classic" or "off")
    local chrome = build(nativeChrome, false)
    chrome.setIconSlotOccupied(true)
    local size = nativeChrome and L.CHROME_BUTTON_SIZE or L.TITLE_BUTTON_SIZE
    local gap = nativeChrome and 2 or L.TITLE_BUTTON_GAP
    local right = leftOffset(chrome.newConversationButton) + 3 * size + 2 * gap -- new, what's new, mark all read
    local minWidth = WindowBounds.GetResizeBounds(chrome.frame:GetParent(), Theme, 1, false, false)
    assert(right + chrome.title:GetStringWidth() / 2 <= minWidth / 2, (nativeChrome and "classic" or "custom") .. ": cluster ends at " .. right)
    Hud.Configure("off")
  end
end
