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

return FiltersSettingsUI
