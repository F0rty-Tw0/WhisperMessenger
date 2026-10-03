local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The Behavior panel's toggle rows, in display order, plus their defaults.
-- Each spec carries its setting `key` and the English `labelKey` it is
-- labelled with, so the panel binds and relabels rows by key.
local ToggleSpecs = {}

ToggleSpecs.DEFAULTS = {
  dimWhenMoving = true,
  autoFocusComposer = false,
  doubleEscapeToClose = false,
  hideOnCombat = false,
}

local function text(key)
  return Localization.Text(key)
end

function ToggleSpecs.Build(config, onChange)
  local profanityEnabled = _G.GetCVar and _G.GetCVar("profanityFilter") == "1" or false

  local specs = {
    {
      key = "dimWhenMoving",
      labelKey = "Dim when moving",
      initial = config.dimWhenMoving ~= false,
      onChange = function(value)
        onChange("dimWhenMoving", value)
      end,
      tooltipLines = {
        text("Dim when moving"),
        text("Reduces window opacity while your character is moving."),
      },
      anchorOffsetY = -24,
    },
    {
      key = "autoFocusComposer",
      labelKey = "Auto-focus chat input",
      initial = config.autoFocusComposer == true,
      onChange = function(value)
        onChange("autoFocusComposer", value)
      end,
      tooltipLines = {
        text("Auto-focus chat input"),
        text("Places the cursor in the text box when you open the messenger."),
      },
    },
    {
      key = "profanityFilter",
      labelKey = "Enable profanity filter",
      initial = profanityEnabled,
      -- Blizzard's game-wide mature-language CVar has no addon default;
      -- "Reset to Defaults" must not silently flip it. Just re-sync the
      -- toggle display to the live value.
      reset = function(control)
        local live = _G.GetCVar and _G.GetCVar("profanityFilter") == "1"
        control.setValue(live == true)
      end,
      onChange = function(value)
        if _G.SetCVar then
          _G.SetCVar("profanityFilter", value and "1" or "0")
        end
      end,
      tooltipLines = {
        text("Enable profanity filter"),
        text("Uses Blizzard's built-in filter to censor profanity in messages."),
      },
    },
    {
      key = "hideOnCombat",
      labelKey = "Hide on entering combat",
      initial = config.hideOnCombat == true,
      onChange = function(value)
        onChange("hideOnCombat", value)
      end,
      tooltipLines = {
        text("Hide on entering combat"),
        text("Hides the messenger when combat starts. You can reopen it manually during combat. It does not reopen automatically after combat."),
      },
    },
    {
      key = "doubleEscapeToClose",
      labelKey = "Double ESC to close",
      initial = config.doubleEscapeToClose == true,
      onChange = function(value)
        onChange("doubleEscapeToClose", value)
      end,
      tooltipLines = {
        text("Double ESC to close"),
        text("First Esc clears the chat input; second Esc closes the window."),
      },
    },
  }
  for _, spec in ipairs(specs) do
    spec.label = text(spec.labelKey)
  end
  return specs
end

ns.MessengerWindowBehaviorToggleSpecs = ToggleSpecs
return ToggleSpecs
