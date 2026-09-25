local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local FakeUI = require("tests.helpers.fake_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Widget and minimap icon tooltips carry the keybinding hints; the reply
-- hint follows the hide-from-default-chat setting.
return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(800, 600)

  rawset(_G, "GetBindingKey", function(action)
    return ({ WHISPERMESSENGER_TOGGLE = "CTRL-O", REPLY = "R" })[action]
  end)
  local lines
  local savedTooltip = _G.GameTooltip
  _G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function(_, text)
      lines[#lines + 1] = text
    end,
    Show = function() end,
    Hide = function() end,
  }
  local function hover(frame)
    lines = {}
    frame:GetScript("OnEnter")(frame)
    return table.concat(lines, "\n")
  end

  local hideFromDefaultChat = false
  local getter = function()
    return hideFromDefaultChat
  end

  local toggle = ToggleIcon.Create(factory, { parent = parent, getHideFromDefaultChat = getter })
  local minimap = MinimapIcon.Create(factory, { parent = parent, getHideFromDefaultChat = getter })

  for _, frame in ipairs({ toggle.frame, minimap.frame }) do
    -- test_icon_tooltip_shows_toggle_binding
    hideFromDefaultChat = false
    local text = hover(frame)
    assert(string.find(text, "Open/close: CTRL-O", 1, true), "toggle hint, got " .. text)
    assert(not string.find(text, "Reply:", 1, true), "no reply hint while Blizzard handles reply")

    -- test_icon_tooltip_shows_reply_binding_when_routed
    hideFromDefaultChat = true
    text = hover(frame)
    assert(string.find(text, "Reply: R", 1, true), "reply hint when routed, got " .. text)
  end

  _G.GameTooltip = savedTooltip
  rawset(_G, "GetBindingKey", nil)
end
