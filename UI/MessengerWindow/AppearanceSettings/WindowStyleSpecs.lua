local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowStyleSpecs = {}

function WindowStyleSpecs.Build(config, onChange, text, gap)
  local phoneLayoutSpec = {
    key = "phoneLayout",
    label = text("Phone-style window"),
    labelKey = "Phone-style window",
    initial = config.phoneLayout ~= false,
    onChange = function(value)
      onChange("phoneLayout", value)
    end,
    tooltipLines = {
      text("Phone-style window"),
      text("The floating button opens a phone-sized chat list attached to it. Click a chat to slide into it."),
    },
    anchorOffsetY = gap,
  }

  local windowAnimationSpec = {
    key = "windowAnimation",
    label = text("Window animation"),
    labelKey = "Window animation",
    initial = config.windowAnimation ~= false,
    onChange = function(value)
      onChange("windowAnimation", value)
    end,
    tooltipLines = {
      text("Window animation"),
      text(
        "The window grows out of its icon when it opens and shrinks back into it when it closes, and pages slide in. Turn it off to make everything appear at once."
      ),
    },
  }

  local openAtSavedSpotSpec = {
    key = "openAtSavedSpot",
    label = text("Open at saved spot"),
    labelKey = "Open at saved spot",
    initial = config.openAtSavedSpot == true,
    onChange = function(value)
      onChange("openAtSavedSpot", value)
    end,
    tooltipLines = {
      text("Open at saved spot"),
      text(
        "The window opens where you last moved it. Turn it off to open the window at the floating button, and move the button along when you move the window."
      ),
    },
  }

  return { phoneLayoutSpec, windowAnimationSpec, openAtSavedSpotSpec }
end

ns.AppearanceSettingsWindowStyleSpecs = WindowStyleSpecs

return WindowStyleSpecs
