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

-- The first `method` width read on `reader` after `hidden` hides fires the
-- strip's OnSizeChanged once (the reads before it happen while the tabs show).
local function fireOnReadAfterHide(toggle, reader, method, hidden)
  local read = reader[method]
  local armed = true
  reader[method] = function(self)
    if armed and hidden.shown == false then
      armed = false
      toggle.frame.scripts.OnSizeChanged(toggle.frame, STRIP_WIDTH, STRIP_HEIGHT)
    end

    return read(self)
  end
end

local function fireSizeChangedOnNextRead(toggle, btn)
  fireOnReadAfterHide(toggle, btn, "GetTextWidth", tab(toggle, "Requests"))
end

-- Modern tabs at 340, all four mode tabs plus Craft Alert.
local function buildModern()
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local toggle = TabToggle.Create(factory, window, { initialMode = "whispers", windowFrame = window })
  toggle.setModes(ALL_MODES)
  toggle.addPanelTab("ca", "Craft Alert", noop)
  toggle.frame:SetWidth(STRIP_WIDTH)
  toggle.frame.scripts.OnSizeChanged(toggle.frame, STRIP_WIDTH, STRIP_HEIGHT)

  return toggle
end

-- A modern tab's label carries its text; the button owns the label.
local function modernLabel(toggle, text)
  local label = FindUI.text(toggle.frame, text)
  assert(label, "no modern tab labelled " .. text)

  return label
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

-- Showing Requests (scrolled out at 340) reads its width before the new list
-- is placed; the resize that read fires lays out the old list, Channels too.
-- test_native_channels_hides_when_showing_a_tab_fires_the_resize
do
  local toggle = build()
  local channels = tab(toggle, "Channels")
  fireOnReadAfterHide(toggle, tab(toggle, "Requests"), "GetTextWidth", channels)
  toggle.setModes({ "whispers", "groups", "requests" })
  assert(channels.shown == false, "Native Channels stays hidden after turning it off")
end

-- test_modern_channels_hides_when_sizing_a_tab_fires_the_resize
do
  local toggle = buildModern()
  local channels = modernLabel(toggle, "Channels").parent
  assert(channels.shown, "modern Channels shows while it is on")
  fireOnReadAfterHide(toggle, modernLabel(toggle, "Whispers"), "GetStringWidth", channels)
  toggle.setModes({ "whispers", "groups", "requests" })
  assert(channels.shown == false, "modern Channels stays hidden after turning it off")
end

print("PASS: test_tab_toggle_resize_reentry")
