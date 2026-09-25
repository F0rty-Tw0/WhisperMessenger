local FakeUI = require("tests.helpers.fake_ui")
local Composer = require("WhisperMessenger.UI.Composer")
local Localization = require("WhisperMessenger.Locale.Localization")

local function build(getSaved, onSend)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 44)
  local contact = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }
  return Composer.Create(factory, parent, contact, onSend or function() end, nil, nil, nil, {
    getQuickReplies = getSaved,
  })
end

local function rowTexts(picker)
  local texts = {}
  for index, row in ipairs(picker.rows) do
    if row:IsShown() then
      texts[index] = row.label:GetText()
    end
  end
  return texts
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_button_opens_default_replies_when_none_saved
  do
    local composer = build(function()
      return nil
    end)
    local button, picker = composer.quickReplyButton, composer.quickReplyPicker
    assert(button ~= nil and picker ~= nil, "quick reply button and picker exist")
    button.scripts.OnClick(button)
    assert(picker.frame:IsShown(), "click opens the quick reply list")
    local texts = rowTexts(picker)
    assert(#texts == 4 and texts[1] == "One sec" and texts[4] == "Sorry, busy right now — will reply soon", "defaults listed")
  end

  -- test_picking_a_reply_inserts_at_cursor_without_sending
  do
    local sends = 0
    local saved = { "brb" }
    local composer = build(function()
      return saved
    end, function()
      sends = sends + 1
    end)
    composer.input:SetText("ok  thanks")
    composer.input:SetCursorPosition(3)
    composer.quickReplyButton.scripts.OnClick(composer.quickReplyButton)
    local row = composer.quickReplyPicker.rows[1]
    row.scripts.OnClick(row)
    assert(composer.input:GetText() == "ok brb thanks", "reply inserted at the cursor, got " .. tostring(composer.input:GetText()))
    assert(sends == 0, "never auto-sends")
    assert(not composer.quickReplyPicker.frame:IsShown(), "list closes after a pick")
    assert(composer.input:HasFocus(), "input focused after a pick")
  end

  -- test_reply_that_does_not_fit_leaves_text_untouched
  do
    local composer = build(function()
      return { "hello" }
    end)
    local full = string.rep("x", 252)
    composer.input:SetText(full)
    composer.quickReplyButton.scripts.OnClick(composer.quickReplyButton)
    local row = composer.quickReplyPicker.rows[1]
    row.scripts.OnClick(row)
    assert(composer.input:GetText() == full, "over-limit reply is not inserted")
  end

  -- test_list_reflects_changes_on_next_open
  do
    local saved = { "a" }
    local composer = build(function()
      return saved
    end)
    local button, picker = composer.quickReplyButton, composer.quickReplyPicker
    button.scripts.OnClick(button)
    picker:close()
    saved = { "b", "c" }
    button.scripts.OnClick(button)
    local texts = rowTexts(picker)
    assert(#texts == 2 and texts[1] == "b" and texts[2] == "c", "reopened list shows the edited replies")
    assert(not picker.rows[3] or not picker.rows[3]:IsShown(), "stale rows hidden")
  end

  -- test_disabled_composer_disables_quick_replies
  do
    local composer = build(function()
      return { "a" }
    end)
    local button, picker = composer.quickReplyButton, composer.quickReplyPicker
    button.scripts.OnClick(button)
    composer.setEnabled(false)
    assert(not picker.frame:IsShown(), "open list closes when the composer is disabled")
    button.scripts.OnClick(button)
    assert(not picker.frame:IsShown(), "disabled button does not open the list")
  end

  -- test_button_tooltip_names_the_action
  do
    local composer = build(function()
      return nil
    end)
    local tooltip = {
      SetOwner = function(self, owner)
        self.owner = owner
      end,
      SetText = function(self, text)
        self.text = text
      end,
      AddLine = function(self, text, r, g, b)
        self.hint, self.hintColor = text, { r, g, b }
      end,
      Show = function() end,
      Hide = function() end,
    }
    local saved = _G.GameTooltip
    _G.GameTooltip = tooltip
    composer.quickReplyButton.scripts.OnEnter(composer.quickReplyButton)
    _G.GameTooltip = saved
    assert(tooltip.text == "Quick replies", "tooltip names the button")

    -- test_button_tooltip_says_where_to_edit_the_list
    assert(tooltip.hint == "Edit this list in Options > Behavior.", "edit hint, got " .. tostring(tooltip.hint))
    local c = tooltip.hintColor
    assert(c[1] == c[2] and c[2] == c[3] and c[1] < 1, "hint line is grey")
  end
end
