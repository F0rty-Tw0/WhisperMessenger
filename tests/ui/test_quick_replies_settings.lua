local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

local function visibleReplies(result)
  local texts = {}
  for _, row in ipairs(result.quickReplies.rows) do
    if row:IsShown() then
      texts[#texts + 1] = row.label:GetText()
    end
  end
  return texts
end

local function build(config, onLayoutChanged)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = BehaviorSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
      config[key] = value
    end,
    onLayoutChanged = onLayoutChanged,
  })
  return result, changes
end

-- Stub StaticPopup: records the shown dialog and hands back a popup whose
-- edit box returns `typed`.
local function stubPopup(typed)
  local shown = {}
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function(name)
    shown.name = name
    shown.popup = {
      editBox = {
        frameType = "EditBox",
        GetText = function()
          return typed
        end,
        SetText = function() end,
      },
    }
    return shown.popup
  end)
  return shown
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_section_lists_default_quick_replies
  do
    local result = build({})
    assert(FindUI.text(result.frame, "Quick replies (4/10)") ~= nil, "section title counts saved replies against the limit")
    local texts = visibleReplies(result)
    assert(#texts == 4 and texts[1] == "One sec", "defaults listed until the player edits them")
  end

  -- test_remove_saves_list_without_entry
  do
    local layoutChanges = 0
    local result, changes = build({ quickReplies = { "a", "b", "c" } }, function()
      layoutChanges = layoutChanges + 1
    end)
    local remove = result.quickReplies.rows[2].removeButton
    remove.scripts.OnClick(remove)
    assert(#changes.quickReplies == 2 and changes.quickReplies[2] == "c", "removal saved")
    local texts = visibleReplies(result)
    assert(#texts == 2 and texts[1] == "a" and texts[2] == "c", "list redrawn after removal")
    assert(layoutChanges == 1, "page asked to re-measure after the list changed")
    assert(FindUI.text(result.frame, "Quick replies (2/10)") ~= nil, "count drops after removal")
  end

  -- test_add_button_opens_dialog_and_saves_new_reply
  do
    local shown = stubPopup("  gg wp ")
    local result, changes = build({ quickReplies = { "a" } })
    local add = FindUI.byLabel(result.frame, "Add quick reply")
    add.scripts.OnClick(add)
    assert(shown.name == "WHISPER_MESSENGER_ADD_QUICK_REPLY", "add opens the quick reply dialog")
    local dialog = _G.StaticPopupDialogs[shown.name]
    assert(dialog.maxBytes == 256, "dialog caps input at one whisper (+ terminator)")
    dialog.OnAccept(shown.popup)
    assert(#changes.quickReplies == 2 and changes.quickReplies[2] == "gg wp", "trimmed reply saved")
    local texts = visibleReplies(result)
    assert(texts[2] == "gg wp", "new reply listed")
    assert(FindUI.text(result.frame, "Quick replies (2/10)") ~= nil, "count rises after adding")

    -- test_enter_in_dialog_confirms
    local hidden = false
    shown.popup.Hide = function()
      hidden = true
    end
    shown.popup.editBox.GetParent = function()
      return shown.popup
    end
    dialog.EditBoxOnEnterPressed(shown.popup.editBox)
    assert(#changes.quickReplies == 3 and hidden, "Enter adds the reply and closes the dialog")
  end

  -- test_add_is_ignored_when_list_is_full
  do
    local shown = stubPopup("x")
    local full = {}
    for index = 1, 10 do
      full[index] = "r" .. index
    end
    local result = build({ quickReplies = full })
    local add = FindUI.byLabel(result.frame, "Add quick reply")
    add.scripts.OnClick(add)
    assert(shown.name == nil, "no dialog once ten replies exist")
  end

  -- test_reset_to_defaults_keeps_quick_replies
  do
    local result, changes = build({ quickReplies = { "mine" } })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset.scripts.OnClick(reset)
    assert(changes.quickReplies == nil, "reset must not wipe typed quick replies")
  end

  -- test_russian_localizes_section
  do
    Localization.Configure({ language = "ruRU" })
    local result = build({})
    assert(FindUI.text(result.frame, "Быстрые ответы (4/10)") ~= nil, "section label translated")
    assert(FindUI.text(result.frame, "Добавить быстрый ответ") ~= nil, "add button translated")
    Localization.Configure({ language = "enUS" })
  end

  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
