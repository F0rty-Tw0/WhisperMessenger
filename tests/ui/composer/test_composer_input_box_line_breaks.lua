local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Composer = require("WhisperMessenger.UI.Composer")
local TextLimits = require("WhisperMessenger.Util.TextLimits")

local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

local function build()
  Fonts.Initialize("default")
  local factory = FakeUI.NewFactory({ wrap = true })
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 44)
  local drafts = {}
  local composer = Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, {
    onDraftChanged = function(_key, text)
      drafts[#drafts + 1] = text
    end,
  })
  return composer, drafts
end

local function paste(input, text, cursor)
  input:SetText(text)
  input:SetCursorPosition(cursor or #text)
  input.scripts.OnTextChanged(input, true)
end

return function()
  -- test_enter_never_leaves_a_line_break
  do
    local composer = build()
    paste(composer.input, "hi\n", 3)
    assert(composer.input:GetText() == "hi", "a typed break is dropped, got " .. string.format("%q", composer.input:GetText()))
  end

  -- test_pasted_breaks_become_spaces
  do
    local composer, drafts = build()
    paste(composer.input, "x\ny\nz", 5)
    assert(composer.input:GetText() == "x y z", "pasted breaks become spaces, got " .. string.format("%q", composer.input:GetText()))
    assert(composer.input:GetCursorPosition() == 5, "the cursor stays at the end")
    assert(drafts[#drafts] == "x y z", "the draft gets the flat text")
  end

  -- test_flattening_reports_the_draft_once
  do
    local composer, drafts = build()
    local input = composer.input
    local rawSetText = input.SetText
    -- The game fires OnTextChanged from SetText.
    input.SetText = function(self, text)
      rawSetText(self, text)
      self.scripts.OnTextChanged(self, false)
    end
    rawSetText(input, "x\ny")
    input:SetCursorPosition(3)
    input.scripts.OnTextChanged(input, true)
    assert(#drafts == 1, "the draft is reported once, got " .. #drafts)
    assert(drafts[1] == "x y", "with the flat text, got " .. tostring(drafts[1]))
  end

  -- test_paste_with_breaks_reaches_the_limit_flattened
  do
    local composer = build()
    composer.setMaxBytes("WOW")
    paste(composer.input, "x\r\ny")
    assert(composer.input:GetText() == "x y", "the first paste is flat")
    paste(composer.input, ("a"):rep(TextLimits.MESSAGE_MAX_BYTES * (TextLimits.MAX_PARTS + 1)) .. "\nb")
    assert(composer.input:GetText() == "x y", "an over-long paste restores the flat text")
    assert(composer.input:GetCursorPosition() == 3, "and its cursor")
  end

  Fonts.Initialize("default")
  print("PASS: test_composer_input_box_line_breaks")
end
