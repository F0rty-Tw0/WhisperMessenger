local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

-- Native tabs drawn tight (up to 8 px narrower) while the strip overflows.
-- Fake text is 7px per character, so Whispers is 7 * 8 + 20 = 76 natural,
-- 68 tight. At 260 the Native room is 260 - 48 - 7 - 2 + 11 = 214; tight
-- Whispers + Groups + Channels = 68 + 54 + 68 + 2 = 192 fits, so the run is
-- drawn tight (natural needs 216).

local ALL_MODES = { "whispers", "groups", "channels", "requests" }
local STRIP_HEIGHT = 32

local function build()
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local toggle = TabToggle.Create(factory, window, { initialMode = "whispers", nativeChrome = true, windowFrame = window })
  toggle.setModes(ALL_MODES)
  return toggle, factory
end

local function whispersTab(toggle)
  for _, btn in ipairs(FindUI.ofType(toggle.frame, "Button")) do
    if btn.text == "Whispers" then
      return btn
    end
  end
  error("no Whispers tab")
end

local function resize(toggle, width)
  toggle.frame:SetWidth(width)
  toggle.frame.scripts.OnSizeChanged(toggle.frame, width, STRIP_HEIGHT)
end

-- test_native_squeeze_survives_the_tab_show_handler
do
  local toggle = build()
  local whispers = whispersTab(toggle)
  resize(toggle, 260)
  assert(whispers:GetWidth() == 68, "drawn tight, got " .. tostring(whispers:GetWidth()))
  whispers:Hide()
  whispers:Show()
  assert(whispers:GetWidth() == 68, "OnShow keeps the squeeze, got " .. tostring(whispers:GetWidth()))
end

-- test_native_squeeze_stops_at_the_edge_art_width
-- Left 40 + Right 34 = 74 > 76 - 8 = 68, so the tight width is 74.
do
  local toggle, factory = build()
  local whispers = whispersTab(toggle)
  whispers.Left = factory.CreateFrame("Frame", nil, nil)
  whispers.Left:SetWidth(40)
  whispers.Right = factory.CreateFrame("Frame", nil, nil)
  whispers.Right:SetWidth(34)
  resize(toggle, 260)
  assert(whispers:GetWidth() == 74, "stops at the art width, got " .. tostring(whispers:GetWidth()))
end

print("PASS: test_tab_toggle_squeeze")
