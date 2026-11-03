local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local AddonGreetings = ns.AddonGreetings or require("WhisperMessenger.Model.AddonGreetings")

-- "Addon greetings" row of the Whispers panel: what to do with a whisper a
-- crafting addon announced as its automated greeting. "Send to Requests" is
-- disabled (value kept) while the Requests inbox is off.
local AddonGreetingsSelector = {}

AddonGreetingsSelector.LABEL = "Addon greetings"

local OPTION_SPECS = {
  {
    key = AddonGreetings.MODE_SHOW,
    label = "Show",
    tooltip = 'Automated greetings from crafting addons show as usual, marked "Sent by" the addon.',
  },
  {
    key = AddonGreetings.MODE_REQUESTS,
    label = "Send to Requests",
    tooltip = "A conversation that starts with a crafting addon's automated greeting waits in Requests.",
    needsRequests = true,
  },
  {
    key = AddonGreetings.MODE_HIDE,
    label = "Hide",
    tooltip = 'Automated greetings from crafting addons are dropped and not saved. While "Hide whispers from default chat" is on, they are not shown anywhere, not even in the game chat.',
  },
}

function AddonGreetingsSelector.Options(requestsInbox)
  local options = {}
  for _, spec in ipairs(OPTION_SPECS) do
    local option = { key = spec.key, label = Localization.Text(spec.label), tooltip = Localization.Text(spec.tooltip) }
    if spec.needsRequests and requestsInbox ~= true then
      option.disabled = true
      option.disabledReason = Localization.Text('Turn on "Put whispers from strangers in Requests" to use this.')
    end
    options[#options + 1] = option
  end
  return options
end

function AddonGreetingsSelector.Create(factory, parent, opts)
  return ButtonSelector.Create(factory, parent, {
    labelText = Localization.Text(AddonGreetingsSelector.LABEL),
    optionsList = AddonGreetingsSelector.Options(opts.requestsInbox),
    fallbackKey = AddonGreetings.DEFAULT_MODE,
    initial = opts.initial,
    onChange = opts.onChange,
    rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
  })
end

ns.MessengerWindowWhispersAddonGreetingsSelector = AddonGreetingsSelector
return AddonGreetingsSelector
