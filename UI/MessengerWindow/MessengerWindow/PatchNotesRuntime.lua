local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

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

ns.MessengerWindowPatchNotesRuntime = PatchNotesRuntime

return PatchNotesRuntime
