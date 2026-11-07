local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
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

-- Runs fn(flush) with C_Timer.After queued; flush() runs what is queued.
local function withQueuedTimers(fn)
  local saved = _G.C_Timer
  local queue = {}
  _G.C_Timer = {
    After = function(_seconds, callback)
      queue[#queue + 1] = callback
    end,
  }
  local ok, err = pcall(fn, function()
    local pending = queue
    queue = {}
    for _, callback in ipairs(pending) do
      callback()
    end
  end)
  _G.C_Timer = saved
  assert(ok, err)
end

-- Counts SetText calls on the panel's edit box from now on.
local function countSetText(panel)
  local box = panel.editBox
  local original = box.SetText
  local calls = { count = 0 }
  box.SetText = function(self, value)
    calls.count = calls.count + 1
    return original(self, value)
  end
  return calls
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

  -- test_text_is_set_again_on_the_next_frame_so_the_box_draws_it
  -- (WoW: Forever leaves the text set while opening undrawn)
  do
    withQueuedTimers(function(flush)
      local panel = show(3)
      local calls = countSetText(panel)
      flush()
      assert(calls.count == 1, "text set again once, got " .. calls.count)
      assert(panel.editBox:GetText() == panel.text, "same text")
      assert(panel.editBox.highlight ~= nil, "still selected for copying")
    end)
  end

  -- test_closed_panel_is_not_redrawn_on_the_next_frame
  do
    withQueuedTimers(function(flush)
      local panel = show(3)
      local calls = countSetText(panel)
      panel:Hide()
      flush()
      assert(calls.count == 0, "hidden panel left alone, got " .. calls.count)
    end)
  end

  -- test_only_the_latest_load_is_redrawn
  do
    withQueuedTimers(function(flush)
      local factory = FakeUI.NewFactory()
      show(450, factory)
      local panel = show(3, factory)
      local calls = countSetText(panel)
      flush()
      assert(calls.count == 1, "stale redraw skipped, got " .. calls.count)
      assert(panel.editBox:GetText() == panel.text, "latest text kept")
    end)
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
