local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
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

-- Runs a script and its hooks, like the game does.
local function fire(frame, event, ...)
  local script = frame:GetScript(event)
  if script then
    script(frame, ...)
  end
  for _, hook in ipairs(frame._hookScripts and frame._hookScripts[event] or {}) do
    hook(frame, ...)
  end
end

-- A client without Blizzard's input scroll template.
local function noTemplateFactory()
  local factory = FakeUI.NewFactory()
  local create = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    if template == "InputScrollFrameTemplate" then
      error("Couldn't find inherited node")
    end
    return create(frameType, name, parent, template)
  end
  return factory
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

  -- test_text_box_is_blizzards_input_scroll_box
  -- (WoW: Forever draws no letters in an edit box inside the addon's own scroll view)
  do
    local panel = show(3)
    local scroll = panel.editBox.parent
    assert(scroll.template == "InputScrollFrameTemplate", "box comes from Blizzard's template, got " .. tostring(scroll.template))
    assert(panel.view == nil, "no addon scroll view")
    assert(scroll:IsShown(), "scroll box shown")
  end

  -- test_template_character_counter_is_hidden
  do
    local panel = show(3)
    assert(not panel.editBox.parent.CharCount:IsShown(), "no characters-left counter")
  end

  -- test_template_box_leaves_room_for_its_scroll_bar
  do
    local panel = show(3)
    local box, scroll = panel.editBox, panel.editBox.parent
    assert(box:GetWidth() > 0 and box:GetWidth() < scroll:GetWidth(), "text narrower than the scroll box, got " .. tostring(box:GetWidth()))
  end

  -- test_modern_look_hides_blizzards_box_art
  do
    local saved = StyledTextInputPopup.nativeChrome
    StyledTextInputPopup.nativeChrome = false
    local ok, err = pcall(function()
      local scroll = show(3).editBox.parent
      local bar = scroll.ScrollBar
      assert(not scroll.BorderTex:IsShown(), "Blizzard border hidden")
      assert(not bar.Track:IsShown(), "Blizzard track hidden")
      assert(not bar.UpButton:IsShown() and not bar.DownButton:IsShown(), "arrow buttons hidden")
      assert(bar:IsShown() and bar:GetThumbTexture():IsShown(), "scroll bar still usable")
      local c, want = bar:GetThumbTexture().color, Theme.COLORS.scrollbar
      assert(c and c[1] == want[1] and c[2] == want[2] and c[3] == want[3], "thumb in the theme's scroll bar colour")
    end)
    StyledTextInputPopup.nativeChrome = saved
    assert(ok, err)
  end

  -- test_native_look_keeps_blizzards_box_art
  do
    local saved = StyledTextInputPopup.nativeChrome
    StyledTextInputPopup.nativeChrome = true
    local ok, err = pcall(function()
      local scroll = show(3).editBox.parent
      assert(scroll.BorderTex:IsShown(), "Blizzard border kept")
      assert(scroll.ScrollBar.UpButton:IsShown(), "arrow buttons kept")
    end)
    StyledTextInputPopup.nativeChrome = saved
    assert(ok, err)
  end

  -- test_template_keeps_its_own_text_handler
  do
    local panel = show(3)
    local before = panel.editBox.templateTextChanges
    fire(panel.editBox, "OnTextChanged", false)
    assert(panel.editBox.templateTextChanges == before + 1, "template still tracks text changes")
  end

  -- test_without_the_template_falls_back_to_the_scroll_view
  do
    local panel = show(450, noTemplateFactory())
    local out = textLines(panel)
    assert(panel.view ~= nil and panel.editBox.parent == panel.view.content, "box scrolls in the addon view")
    assert(#out == 451 and out[451] == "line 450", "every line, got " .. #out)
  end

  -- test_fallback_text_uses_the_game_chat_font
  do
    local panel = show(3, noTemplateFactory())
    assert(_G.ChatFontNormal ~= nil, "fake UI provides ChatFontNormal")
    assert(panel.editBox.fontObject == _G.ChatFontNormal, "box uses ChatFontNormal")
  end

  -- test_fallback_text_uses_the_addon_font_without_the_chat_font
  do
    local saved = _G.ChatFontNormal
    _G.ChatFontNormal = nil
    local ok, err = pcall(function()
      local panel = show(3, noTemplateFactory())
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
    fire(panel.editBox, "OnTextChanged", true)
    assert(panel.editBox:GetText() == before, "player edits are undone")
    local fallback = show(3, noTemplateFactory())
    fallback.editBox:SetText("typed over")
    fire(fallback.editBox, "OnTextChanged", true)
    assert(fallback.editBox:GetText() == before, "fallback undoes player edits too")
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
