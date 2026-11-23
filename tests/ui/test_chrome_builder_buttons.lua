local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")
local Buttons = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.Buttons")

-- Records GameTooltip lines while fn runs.
local function withTooltip(fn)
  local saved = _G.GameTooltip
  local tip = { lines = {} }
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, value)
      tip.title = value
    end,
    AddLine = function(_, value)
      tip.lines[#tip.lines + 1] = value
    end,
    Show = function() end,
    Hide = function() end,
  }
  local ok, err = pcall(fn, tip)
  _G.GameTooltip = saved
  assert(ok, err)
end

local function newFrame()
  local factory = FakeUI.NewFactory()
  return factory, factory.CreateFrame("Frame", nil, nil)
end

local function isEmphasized(result)
  local color = result.icon.vertexColor
  local primary = Theme.COLORS.text_primary
  return color[1] == primary[1] and color[2] == primary[2] and color[3] == primary[3]
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_plain_icon_hint_key_adds_a_second_tooltip_line
  withTooltip(function(tip)
    local factory, frame = newFrame()
    local result = Buttons.CreatePlainIcon(factory, frame, Theme, "title_whats_new_icon", "What's New", {
      hintKey = "See what changed in the latest update.",
    })
    result.button:GetScript("OnEnter")(result.button)
    assert(tip.title == "What's New", "the title line")
    assert(tip.lines[1] == "See what changed in the latest update.", "the localized hint under it")
  end)

  -- test_plain_icon_without_hint_shows_one_line
  withTooltip(function(tip)
    local factory, frame = newFrame()
    local result = Buttons.CreatePlainIcon(factory, frame, Theme, "title_back_icon", "Back")
    result.button:GetScript("OnEnter")(result.button)
    assert(tip.title == "Back" and #tip.lines == 0, "one line only")
  end)

  -- test_plain_icon_desaturate_option_greys_the_icon
  do
    local factory, frame = newFrame()
    local grey = Buttons.CreatePlainIcon(factory, frame, Theme, "title_settings_icon", "Options", { desaturate = true })
    local plain = Buttons.CreatePlainIcon(factory, frame, Theme, "title_whats_new_icon", "What's New")
    assert(grey.icon.desaturated == true, "desaturate greys the icon")
    assert(plain.icon.desaturated ~= true, "without it the icon keeps its colours")
  end

  -- test_plain_icon_active_state_survives_leave
  do
    local factory, frame = newFrame()
    local result = Buttons.CreatePlainIcon(factory, frame, Theme, "title_settings_icon", "Options")
    assert(not isEmphasized(result), "idle paint at rest")
    result.setActive(true)
    assert(isEmphasized(result), "active paints like hover")
    result.button:GetScript("OnLeave")(result.button)
    assert(isEmphasized(result), "leaving keeps the active paint")
    result.setActive(false)
    assert(not isEmphasized(result), "inactive goes back to idle")
  end

  -- test_new_whisper_and_options_keep_their_look
  withTooltip(function(tip)
    local factory, frame = newFrame()
    local newWhisper = Buttons.CreateNewConversation(factory, frame, Theme)
    local options = Buttons.CreateOptions(factory, frame, Theme)
    assert(newWhisper.icon.desaturated == true and options.icon.desaturated == true, "both icons stay grey")
    newWhisper.button:GetScript("OnEnter")(newWhisper.button)
    assert(tip.title == "Start New Whisper" and tip.lines[1] == "Open an empty conversation thread.", "new whisper keeps its hint")
    options.setActive(true)
    assert(isEmphasized(options), "options shows its active paint")
  end)
end
