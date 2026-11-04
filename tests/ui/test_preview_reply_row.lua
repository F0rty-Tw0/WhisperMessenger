local FakeUI = require("tests.helpers.fake_ui")
local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")
local ComposerLimit = require("WhisperMessenger.UI.Composer.ComposerLimit")
local PreviewMetrics = require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewReplyRow = require("WhisperMessenger.UI.ToggleIcon.PreviewReplyRow")

local function build()
  local factory = FakeUI.NewFactory()
  local card = factory.CreateFrame("Frame", nil, nil)
  card:Show()
  local log = { submits = {}, holds = {}, focusGained = 0, disabledClicks = 0 }
  log.row = PreviewReplyRow.Create(factory, card, {
    onSubmit = function(text)
      log.submits[#log.submits + 1] = text
      return true
    end,
    onHoldChanged = function(holding)
      log.holds[#log.holds + 1] = holding
    end,
    onFocusGained = function()
      log.focusGained = log.focusGained + 1
    end,
    onDisabledClick = function()
      log.disabledClicks = log.disabledClicks + 1
    end,
  })
  log.row.setShown(true)
  return log
end

local function fire(frame, script, ...)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "row has a " .. script .. " handler")
  handler(frame, ...)
end

local function typeText(row, text)
  row.input:SetText(text)
  fire(row.input, "OnTextChanged", true)
end

local function enter(row)
  fire(row.input, "OnEnterPressed")
end

return function()
  local function test_enter_submits_raw_text_and_keeps_it()
    local log = build()
    typeText(log.row, "  hi ")
    enter(log.row)
    assert(#log.submits == 1 and log.submits[1] == "  hi ", "Enter submits the raw text once")
    assert(log.row.input:GetText() == "  hi ", "the row keeps its text after a submit")
  end

  local function test_empty_and_whitespace_enter_is_ignored()
    local log = build()
    enter(log.row)
    typeText(log.row, "   ")
    enter(log.row)
    assert(#log.submits == 0, "empty and blank text submit nothing, got " .. #log.submits)
  end

  local function test_send_arrow_submits_like_enter()
    local log = build()
    typeText(log.row, "hi")
    fire(log.row.sendButton, "OnClick")
    assert(#log.submits == 1 and log.submits[1] == "hi", "the send arrow submits the text")
  end

  local function test_escape_clears_focus_and_keeps_text()
    local log = build()
    log.row.input:SetFocus()
    typeText(log.row, "brb")
    fire(log.row.input, "OnEscapePressed")
    assert(log.row.input:HasFocus() == false, "ESC drops focus")
    assert(log.row.getText() == "brb", "ESC keeps the text")
    assert(log.row.isHolding() == true, "text alone keeps the hold")
  end

  local function test_hold_transitions_fire_once_each()
    local log = build()
    log.row.input:SetFocus()
    assert(#log.holds == 1 and log.holds[1] == true, "focus starts the hold")
    typeText(log.row, "hi")
    log.row.input:ClearFocus()
    assert(#log.holds == 1, "typing and blurring with text fire nothing, got " .. #log.holds)
    log.row.clear()
    assert(#log.holds == 2 and log.holds[2] == false, "clear ends the hold once")
    assert(log.row.getText() == "", "clear empties the input")
    assert(log.row.placeholder:IsShown(), "clear shows the placeholder")
  end

  local function test_disabled_row_shows_reason_and_ignores_submit()
    local log = build()
    typeText(log.row, "hi")
    log.row.setEnabled(false, "Competitive Content")
    assert(log.row.isEnabled() == false, "the row reports disabled")
    assert(log.row.placeholder:GetText() == "Competitive Content", "the placeholder shows the reason")
    assert(log.row.cover:IsShown(), "the cover is up")
    enter(log.row)
    fire(log.row.sendButton, "OnClick")
    assert(#log.submits == 0, "a disabled row submits nothing")
    fire(log.row.cover, "OnMouseDown", "LeftButton")
    assert(log.disabledClicks == 1, "a click on the cover reports once")
    log.row.setEnabled(true)
    assert(log.row.isEnabled() and not log.row.cover:IsShown(), "enabling drops the cover")
    assert(log.row.placeholder:GetText() == "Reply…", "enabling restores the placeholder")
  end

  local function test_focus_while_disabled_is_dropped()
    local log = build()
    log.row.setEnabled(false, "Mythic Lockdown")
    log.row.input:SetFocus()
    assert(log.row.input:HasFocus() == false, "a disabled row refuses focus")
    assert(#log.holds == 0, "no hold event, got " .. #log.holds)
    assert(log.focusGained == 0, "no onFocusGained")
    log.row.focus()
    assert(log.row.input:HasFocus() == false, "focus() does nothing while disabled")
  end

  local function test_whisper_cap_undoes_a_fifth_part()
    local log = build()
    log.row.setTarget("WOW")
    assert(log.row.input.maxBytes == ComposerLimit.InputMaxBytes("WOW"), "the input takes the whisper cap")
    typeText(log.row, "ok")
    typeText(log.row, string.rep("a", 255 * 4 + 1))
    assert(log.row.getText() == "ok", "a fifth part is undone, got " .. #log.row.getText() .. " bytes")
  end

  local function test_input_registers_with_link_hooks()
    local original = rawget(LinkHooks, "RegisterInput")
    local registered = {}
    rawset(LinkHooks, "RegisterInput", function(input)
      registered[#registered + 1] = input
    end)
    local ok, err = pcall(build)
    rawset(LinkHooks, "RegisterInput", original)
    assert(ok, err)
    assert(#registered == 1 and registered[1] == err.row.input, "the input registers with LinkHooks once")
  end

  local function test_secret_text_reads_as_empty()
    local original = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(v)
      return v == "SECRET"
    end)
    local ok, err = pcall(function()
      local log = build()
      log.row.input:SetText("SECRET")
      assert(log.row.getText() == "", "a secret reads as empty")
      assert(log.row.isHolding() == false, "a secret alone does not hold")
    end)
    rawset(_G, "issecretvalue", original)
    assert(ok, err)
  end

  local function test_no_auto_focus()
    local log = build()
    assert(log.row.input.autoFocus == false, "the input never takes focus on show")
  end

  local function test_height_is_row_plus_gap()
    local log = build()
    assert(log.row.height() == PreviewMetrics.REPLY_ROW_HEIGHT + PreviewMetrics.REPLY_ROW_GAP, "height is row plus gap")
  end

  test_enter_submits_raw_text_and_keeps_it()
  test_empty_and_whitespace_enter_is_ignored()
  test_send_arrow_submits_like_enter()
  test_escape_clears_focus_and_keeps_text()
  test_hold_transitions_fire_once_each()
  test_disabled_row_shows_reason_and_ignores_submit()
  test_focus_while_disabled_is_dropped()
  test_whisper_cap_undoes_a_fifth_part()
  test_input_registers_with_link_hooks()
  test_secret_text_reads_as_empty()
  test_no_auto_focus()
  test_height_is_row_plus_gap()
end
