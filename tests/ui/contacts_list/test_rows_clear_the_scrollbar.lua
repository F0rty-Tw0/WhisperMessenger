rawset(_G, "time", os.time)
_G.date = os.date

local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ContactsController = require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

local PANE_WIDTH = 260
local PANE_HEIGHT = 120
local OPTIONS = { onSelect = function() end, onPin = function() end, onRemove = function() end }

local function contacts(count)
  local list = {}
  for i = 1, count do
    list[i] = {
      conversationKey = "me::WOW::c" .. i,
      displayName = "Contact" .. i,
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 100 - i,
      channel = "WOW",
    }
  end
  return list
end

-- A fresh list long enough to overflow on its very first refresh.
local function overflowingList(style)
  Hud.Configure(style)
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(PANE_WIDTH, PANE_HEIGHT)
  local view = ScrollView.Create(factory, pane, { width = PANE_WIDTH, height = PANE_HEIGHT, step = Theme.LAYOUT.CONTACT_ROW_HEIGHT })
  local controller = ContactsController.Create(factory, view, {}, OPTIONS)
  local rows = controller.refresh(contacts(20), nil, true)
  Hud.Configure("off")
  return view, rows
end

return function()
  -- test_hud_rows_stop_short_of_the_knob_on_the_first_overflowing_refresh
  do
    local view, rows = overflowingList("classic")
    local contentWidth = view.content.width
    assert(contentWidth == PANE_WIDTH - Theme.LAYOUT.SCROLLBAR_WIDTH_HUD, "HUD: content leaves the knob gutter, got " .. tostring(contentWidth))
    assert(rows[1].width <= contentWidth, "HUD: row fits beside the knob, got " .. tostring(rows[1].width) .. " in " .. tostring(contentWidth))
  end

  -- test_modern_rows_stop_short_of_the_bar_on_the_first_overflowing_refresh
  do
    local view, rows = overflowingList("off")
    local contentWidth = view.content.width
    assert(contentWidth == PANE_WIDTH - Theme.LAYOUT.SCROLLBAR_WIDTH, "modern: content leaves the thin gutter, got " .. tostring(contentWidth))
    assert(rows[1].width <= contentWidth, "modern: row fits beside the bar, got " .. tostring(rows[1].width) .. " in " .. tostring(contentWidth))
  end
end
