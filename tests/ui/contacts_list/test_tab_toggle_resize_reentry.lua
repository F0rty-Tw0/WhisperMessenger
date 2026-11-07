local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

-- The real client fires a strip's OnSizeChanged synchronously from a width
-- read that changes its size; the fake never does, so these tests fire it from
-- inside a tab's text-width read, the way the client does.
-- Native tabs at 340 (fake text 7px per character): Whispers 76, Groups 62,
-- Channels 76, Requests 76, Craft Alert 97; the five overflow, the four
-- without Requests fit natural (76 + 62 + 76 + 97 + 3 = 314 <= 333).

local STRIP_WIDTH = 340
local STRIP_HEIGHT = 32
local ALL_MODES = { "whispers", "groups", "channels", "requests" }
local NO_REQUESTS = { "whispers", "groups", "channels" }

local function noop() end

local function build()
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local toggle = TabToggle.Create(factory, window, { initialMode = "whispers", nativeChrome = true, windowFrame = window })
  toggle.setModes(ALL_MODES)
  toggle.addPanelTab("ca", "Craft Alert", noop)
  toggle.frame:SetWidth(STRIP_WIDTH)
  toggle.frame.scripts.OnSizeChanged(toggle.frame, STRIP_WIDTH, STRIP_HEIGHT)

  return toggle
end

-- Errors when no tab carries the label.
local function tab(toggle, label)
  for _, btn in ipairs(FindUI.ofType(toggle.frame, "Button")) do
    if btn.text == label then
      return btn
    end
  end
  error("no tab labelled " .. label)
end

-- The first width read on `btn` after Requests is hidden fires the strip's
-- OnSizeChanged once (the reads before it happen while the tabs show).
local function fireSizeChangedOnNextRead(toggle, btn)
  local read = btn.GetTextWidth
  local requests = tab(toggle, "Requests")
  local armed = true
  btn.GetTextWidth = function(self)
    if armed and requests.shown == false then
      armed = false
      toggle.frame.scripts.OnSizeChanged(toggle.frame, STRIP_WIDTH, STRIP_HEIGHT)
    end

    return read(self)
  end
end

-- test_native_requests_tab_hides_when_a_width_read_fires_the_resize
do
  local toggle = build()
  assert(tab(toggle, "Requests").shown, "Requests shows while it is on")
  fireSizeChangedOnNextRead(toggle, tab(toggle, "Whispers"))
  toggle.setModes(NO_REQUESTS)
  assert(tab(toggle, "Requests").shown == false, "Requests stays hidden after the re-entrant resize")
end

-- test_native_craft_alert_anchors_after_channels_when_requests_is_off
do
  local toggle = build()
  fireSizeChangedOnNextRead(toggle, tab(toggle, "Whispers"))
  toggle.setModes(NO_REQUESTS)
  local point = tab(toggle, "Craft Alert").points[1]
  assert(point[2] == tab(toggle, "Channels"), "Craft Alert anchors to Channels")
  assert(point[3] == "TOPRIGHT", "Craft Alert hangs off Channels' right edge")
  assert(tab(toggle, "Craft Alert").shown, "Craft Alert shows")
end

print("PASS: test_tab_toggle_resize_reentry")
