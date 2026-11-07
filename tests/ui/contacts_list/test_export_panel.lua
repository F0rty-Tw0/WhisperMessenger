local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local Theme = require("WhisperMessenger.UI.Theme")
local ExportPanel = require("WhisperMessenger.UI.ContactsList.ExportPanel")

-- The export panel shows a whole conversation as copyable text.

local HEADER = "Conversation with Arthas"

local function numbered(count)
  local lines = {}
  for index = 1, count do
    lines[index] = "line " .. index
  end
  return lines
end

local function show(count, factory)
  return ExportPanel.Show({ title = "Arthas", header = HEADER, lines = numbered(count) }, factory or FakeUI.NewFactory())
end

local function textLines(panel)
  local out = {}
  for line in string.gmatch(panel.editBox:GetText() .. "\n", "(.-)\n") do
    out[#out + 1] = line
  end
  return out
end

local function status(panel)
  return panel.status:GetText()
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_opens_with_every_line_under_the_header
  do
    local panel = show(450)
    local out = textLines(panel)
    assert(panel:IsShown(), "panel shown")
    assert(#out == 451, "header plus all 450 lines, got " .. #out)
    assert(out[1] == HEADER, "header first, got " .. tostring(out[1]))
    assert(out[2] == "line 1" and out[451] == "line 450", "every line, oldest first, got " .. tostring(out[2]))
    assert(status(panel) == "450 lines · Ctrl+C copies", "status counts, got " .. tostring(status(panel)))
  end

  -- test_title_names_the_contact
  do
    local panel = show(1)
    assert(FindUI.text(panel, "Export: Arthas") ~= nil, "title names the contact")
  end

  -- test_text_is_selected_for_copying_and_uncapped
  do
    local panel = show(3)
    assert(panel.editBox.highlight ~= nil, "text is selected after loading")
    assert(panel.editBox.maxLetters == 0, "no letter cap")
    assert(panel.editBox.multiline == true, "multi-line box")
  end

  -- test_has_no_paging_buttons
  do
    local panel = show(450)
    assert(FindUI.text(panel, "Show more") == nil, "no show more button")
    assert(FindUI.text(panel, "Show all") == nil, "no show all button")
  end

  -- test_empty_conversation_shows_only_the_header
  do
    local panel = show(0)
    local out = textLines(panel)
    assert(#out == 1 and out[1] == HEADER, "just the header, got " .. #out .. " lines")
    assert(status(panel) == "0 lines · Ctrl+C copies", "zero count, got " .. tostring(status(panel)))
  end

  -- test_reopening_shows_only_the_new_lines
  do
    local factory = FakeUI.NewFactory()
    local panel = show(450, factory)
    local again = show(3, factory)
    local out = textLines(again)
    assert(again == panel, "one panel, reused")
    assert(#out == 4 and out[4] == "line 3", "header plus the 3 new lines, got " .. #out)
    assert(status(again) == "3 lines · Ctrl+C copies", "status counts the new lines, got " .. tostring(status(again)))
  end

  -- test_text_uses_the_game_chat_font
  -- (WoW: Forever draws nothing in this box with the addon's own font)
  do
    local panel = show(3)
    assert(_G.ChatFontNormal ~= nil, "fake UI provides ChatFontNormal")
    assert(panel.editBox.fontObject == _G.ChatFontNormal, "box uses ChatFontNormal")
  end

  -- test_text_falls_back_to_the_addon_font_without_the_chat_font
  do
    local saved = _G.ChatFontNormal
    _G.ChatFontNormal = nil
    local ok, err = pcall(function()
      local panel = show(3)
      local expected = _G[Theme.FONTS.composer_input] or Theme.FONTS.composer_input
      assert(panel.editBox.fontObject == expected, "box falls back to the composer font, got " .. tostring(panel.editBox.fontObject))
    end)
    _G.ChatFontNormal = saved
    assert(ok, err)
  end

  -- test_typing_does_not_change_the_text
  do
    local panel = show(3)
    local before = panel.editBox:GetText()
    panel.editBox:SetText("typed over")
    panel.editBox:GetScript("OnTextChanged")(panel.editBox, true)
    assert(panel.editBox:GetText() == before, "player edits are undone")
  end

  -- test_close_button_and_escape_hide_the_panel
  do
    local panel = show(3)
    FindUI.click(panel.closeButton)
    assert(not panel:IsShown(), "close button hides it")
    panel = show(3)
    panel.editBox:GetScript("OnEscapePressed")(panel.editBox)
    assert(not panel:IsShown(), "Esc in the text hides it")
  end

  -- test_escape_closes_it_through_ui_special_frames
  do
    local savedSpecial = _G.UISpecialFrames
    _G.UISpecialFrames = {}
    local reported = nil
    PickerPopup.SetEscapeFrameShownHandler(function(shown)
      reported = shown
    end)
    local ok, err = pcall(function()
      local panel = show(3)
      assert(_G.UISpecialFrames[1] == ExportPanel.FRAME_NAME, "panel closes on ESC")
      assert(reported == panel, "opening the panel takes ESC from the messenger")
    end)
    PickerPopup.SetEscapeFrameShownHandler(nil)
    _G.UISpecialFrames = savedSpecial
    assert(ok, err)
  end
end
