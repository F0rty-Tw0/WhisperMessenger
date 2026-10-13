local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PatchNotes = ns.PatchNotes or require("WhisperMessenger.Core.PatchNotes")
local SettingsPanels = ns.MessengerWindowSettingsPanels or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

local PatchNotesRuntime = {}

-- Wires the title-bar "?" button to the What's New options page. The button
-- glows while the shipped patch-notes version differs from the one stored in
-- the account settings, which covers a fresh install (nothing stored) and
-- every later update. Opening the page records the version and stops the glow.
--
-- settingsConfig IS accountState.settings (SavedVariables), so the seen
-- version is written straight onto it — the same way windowScale is stored.
function PatchNotesRuntime.Wire(options)
  options = options or {}

  local button = options.button
  local tab = options.tab
  local setGlowing = options.setGlowing
  local settingsConfig = options.settingsConfig or {}
  local patchNotes = options.patchNotes or ns.PatchNotes or {}
  local openPage = options.openPage

  local function isUnseen()
    return settingsConfig.patchNotesSeenVersion ~= patchNotes.version
  end

  local function markSeen()
    settingsConfig.patchNotesSeenVersion = patchNotes.version
    if setGlowing then
      setGlowing(false)
    end
  end

  if setGlowing then
    setGlowing(isUnseen())
  end

  if button and button.SetScript then
    button:SetScript("OnClick", function()
      if openPage then
        openPage()
      end
      markSeen()
    end)
  end

  -- Reaching the page through the Options sidebar counts as seeing it, so
  -- hook the tab's own click rather than replacing its handler.
  if tab and tab.HookScript then
    tab:HookScript("OnClick", markSeen)
  end

  return { isUnseen = isUnseen, markSeen = markSeen }
end

-- Wires the window's "?" button: clicking opens Options on the What's New
-- page; the sidebar tab clears the glow too, so either route counts as
-- seeing the notes. Hides the button when no patch notes shipped.
-- options: chrome, layout, settingsConfig, setOptionsVisible, scriptResult
function PatchNotesRuntime.Attach(options)
  local chrome = options.chrome
  local button = chrome.patchNotesButton
  if PatchNotes ~= nil and button ~= nil then
    local scriptResult = options.scriptResult
    PatchNotesRuntime.Wire({
      button = button,
      tab = options.layout.whatsNewTab,
      setGlowing = chrome.setPatchNotesGlow,
      settingsConfig = options.settingsConfig,
      patchNotes = PatchNotes,
      openPage = function()
        options.setOptionsVisible(true)
        if scriptResult.selectSettingsTab then
          scriptResult.selectSettingsTab(SettingsPanels.PATCH_NOTES_INDEX)
        end
      end,
    })
  elseif button ~= nil and button.Hide then
    button:Hide()
  end
end

ns.MessengerWindowPatchNotesRuntime = PatchNotesRuntime

return PatchNotesRuntime
