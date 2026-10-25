local FakeUI = require("tests.helpers.fake_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

local function noop() end

local function build(native, clampBottom)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  if clampBottom then
    window:SetClampRectInsets(0, 0, 0, clampBottom)
  end
  local toggle = TabToggle.Create(factory, window, { initialMode = "whispers", nativeChrome = native, windowFrame = window })
  return toggle, window
end

return function()
  for _, native in ipairs({ false, true }) do
    local label = native and "HUD" or "modern"

    -- test_strip_shows_with_one_mode_and_one_panel_tab
    do
      local toggle = build(native)
      toggle.setModes({ "whispers" })
      assert(toggle.frame:IsShown() == false, label .. ": Whispers alone hides the strip")
      toggle.addPanelTab("ca", "Alerts", noop)
      assert(toggle.frame:IsShown() == true, label .. ": Whispers + addon tab shows the strip")
    end

    -- test_options_hide_the_strip
    do
      local toggle = build(native)
      toggle.setModes({ "whispers", "groups" })
      toggle.setOptionsShown(true)
      assert(toggle.frame:IsShown() == false, label .. ": options page hides the strip")
      toggle.setOptionsShown(false)
      assert(toggle.frame:IsShown() == true, label .. ": closing options shows it again")
    end

    -- test_add_panel_tab_while_options_shown_keeps_strip_hidden
    do
      local toggle = build(native)
      toggle.setModes({ "whispers" })
      toggle.setOptionsShown(true)
      toggle.addPanelTab("ca", "Alerts", noop)
      assert(toggle.frame:IsShown() == false, label .. ": a new tab under options keeps the strip hidden")
      toggle.setOptionsShown(false)
      assert(toggle.frame:IsShown() == true, label .. ": shown once options close")
    end
  end

  -- test_shown_goes_through_the_skin_clamp
  do
    local toggle, window = build(false, 3)
    toggle.setModes({ "whispers", "groups" })
    local bottom = select(4, window:GetClampRectInsets())
    assert(bottom == 3 - TabToggle.HEIGHT, "modern: clamp extends with the shown strip, got " .. tostring(bottom))
  end
end
