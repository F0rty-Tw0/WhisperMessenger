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
      text("The window grows out of its icon when it opens and shrinks back into it when it closes. Turn it off to open and close it at once."),
    },
  }

  return { phoneLayoutSpec, windowAnimationSpec }
end

ns.AppearanceSettingsWindowStyleSpecs = WindowStyleSpecs

return WindowStyleSpecs
