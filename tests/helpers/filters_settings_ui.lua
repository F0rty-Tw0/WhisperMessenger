local Theme = require("WhisperMessenger.UI.Theme")

-- Shared by the Filters page tests: find the shown remove buttons and answer
-- text dialogs.
local FiltersSettingsUI = {}

-- Shown remove buttons (trash icon), in tree order.
function FiltersSettingsUI.trashButtons(root)
  local buttons = {}
  local function walk(node)
    for _, child in ipairs(node.children or {}) do
      if child.texturePath == Theme.TEXTURES.trash_icon and child.parent.parent:IsShown() then
        buttons[#buttons + 1] = child.parent
      end
      walk(child)
    end
  end
  walk(root)
  return buttons
end

-- Each StaticPopup_Show accepts at once with the next queued text.
function FiltersSettingsUI.stubPopups(answers)
  local shown = {}
  _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
  rawset(_G, "StaticPopup_Show", function(name)
    local typed = table.remove(answers, 1)
    shown[#shown + 1] = name
    _G.StaticPopupDialogs[name].OnAccept({
      editBox = {
        frameType = "EditBox",
        GetText = function()
          return typed
        end,
        SetText = function() end,
      },
    })
  end)
  return shown
end

-- Replaces TwoFieldDialog.Show: records each spec and, for each queued
-- { name, words } answer, accepts at once (no answer leaves it open).
-- Returns the recorded specs and a function that puts Show back.
function FiltersSettingsUI.stubTwoFieldDialog(answers)
  local TwoFieldDialog = require("WhisperMessenger.UI.Shared.TwoFieldDialog")
  local original = TwoFieldDialog.Show
  local specs = {}
  rawset(TwoFieldDialog, "Show", function(_factory, spec)
    specs[#specs + 1] = spec
    local answer = table.remove(answers, 1)
    if answer then
      spec.onAccept(answer[1], answer[2])
    end
  end)
  return specs, function()
    rawset(TwoFieldDialog, "Show", original)
  end
end

return FiltersSettingsUI
