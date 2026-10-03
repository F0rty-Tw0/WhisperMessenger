local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TwoFieldDialog = require("WhisperMessenger.UI.Shared.TwoFieldDialog")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")

-- A popup with two labelled inputs: an optional first field and a required
-- second one. Enter and Tab move between them, Enter on the second accepts,
-- Escape and Cancel close.

local function show(factory, overrides)
  local result = {}
  local spec = {
    title = "Add rule…",
    accept = "Add",
    firstLabel = "Name (optional)",
    secondLabel = "Words",
    hint = "wts/wtb: either word is enough.",
    firstMaxLetters = 48,
    secondMaxLetters = 255,
    onAccept = function(first, second)
      result.accepted = { first = first, second = second }
    end,
  }
  for key, value in pairs(overrides or {}) do
    spec[key] = value
  end
  result.dialog = TwoFieldDialog.Show(factory, spec)
  return result
end

local function typeInto(box, text)
  box:SetText(text)
  local onTextChanged = box:GetScript("OnTextChanged")
  if onTextChanged then
    onTextChanged(box, true)
  end
end

local function press(box, scriptName)
  box:GetScript(scriptName)(box)
end

return function()
  local savedNative = StyledTextInputPopup.nativeChrome
  StyledTextInputPopup.nativeChrome = false

  -- test_show_fills_title_labels_hint_and_buttons
  do
    local result = show(FakeUI.NewFactory())
    local dialog = result.dialog
    assert(dialog:IsShown(), "dialog shown")
    for _, label in ipairs({ "Add rule…", "Name (optional)", "Words", "wts/wtb: either word is enough." }) do
      assert(FindUI.text(dialog, label) ~= nil, "shows " .. label)
    end
    assert(FindUI.byLabel(dialog, "Add") ~= nil and FindUI.byLabel(dialog, "Cancel") ~= nil, "accept and cancel buttons")
    assert(dialog.firstInput:HasFocus(), "the first field takes focus")
  end

  -- test_show_primes_both_fields
  do
    local dialog = show(FakeUI.NewFactory(), { firstValue = "Boost", secondValue = "wts + boost" }).dialog
    assert(dialog.firstInput:GetText() == "Boost" and dialog.secondInput:GetText() == "wts + boost", "fields primed")
  end

  -- test_accept_hands_back_trimmed_texts_and_closes
  do
    local result = show(FakeUI.NewFactory())
    typeInto(result.dialog.firstInput, "  Boost  ")
    typeInto(result.dialog.secondInput, " wts boost ")
    FindUI.click(FindUI.byLabel(result.dialog, "Add"))
    assert(result.accepted and result.accepted.first == "Boost" and result.accepted.second == "wts boost", "texts handed back")
    assert(not result.dialog:IsShown(), "closed on accept")
  end

  -- test_accept_waits_for_the_second_field
  do
    local result = show(FakeUI.NewFactory())
    local acceptButton = result.dialog.acceptButton
    assert(acceptButton.enabled == false, "accept disabled while the second field is empty")
    FindUI.click(acceptButton)
    assert(result.accepted == nil and result.dialog:IsShown(), "nothing accepted, still open")
    typeInto(result.dialog.secondInput, "wts")
    assert(acceptButton.enabled == true, "accept enabled once words are typed")
  end

  -- test_enter_in_first_moves_to_second_and_enter_in_second_accepts
  do
    local result = show(FakeUI.NewFactory())
    press(result.dialog.firstInput, "OnEnterPressed")
    assert(result.dialog.secondInput:HasFocus(), "Enter moves to the second field")
    typeInto(result.dialog.secondInput, "wts")
    press(result.dialog.secondInput, "OnEnterPressed")
    assert(result.accepted and result.accepted.second == "wts" and result.accepted.first == "", "Enter accepts")
  end

  -- test_tab_switches_fields
  do
    local dialog = show(FakeUI.NewFactory()).dialog
    press(dialog.firstInput, "OnTabPressed")
    assert(dialog.secondInput:HasFocus(), "Tab to the second field")
    press(dialog.secondInput, "OnTabPressed")
    assert(dialog.firstInput:HasFocus(), "Tab back to the first field")
  end

  -- test_escape_and_cancel_close_without_accepting
  do
    local result = show(FakeUI.NewFactory(), { secondValue = "wts" })
    press(result.dialog.secondInput, "OnEscapePressed")
    assert(not result.dialog:IsShown() and result.accepted == nil, "Escape closes")
    result = show(FakeUI.NewFactory(), { secondValue = "wts" })
    FindUI.click(FindUI.byLabel(result.dialog, "Cancel"))
    assert(not result.dialog:IsShown() and result.accepted == nil, "Cancel closes")
  end

  -- test_reopening_reuses_the_frame_and_clears_old_text
  do
    local factory = FakeUI.NewFactory()
    local first = show(factory, { firstValue = "Old", secondValue = "old words" }).dialog
    local second = show(factory).dialog
    assert(first == second, "one frame per factory")
    assert(second.firstInput:GetText() == "" and second.secondInput:GetText() == "", "fields cleared")
  end

  -- test_native_hud_uses_blizzard_inputs_and_buttons
  do
    StyledTextInputPopup.nativeChrome = true
    local dialog = show(FakeUI.NewFactory()).dialog
    assert(dialog.firstInput.template == "InputBoxTemplate" and dialog.secondInput.template == "InputBoxTemplate", "Blizzard input boxes")
    assert(dialog.acceptButton.template == "UIPanelButtonTemplate", "Blizzard panel buttons")
    StyledTextInputPopup.nativeChrome = false
  end

  -- test_native_hud_backs_the_see_through_dialog_art_with_a_dark_fill
  do
    StyledTextInputPopup.nativeChrome = true
    local fill = show(FakeUI.NewFactory()).dialog.nativeFill
    assert(fill ~= nil and fill.alpha >= 0.9, "dark fill at least 90% opaque")
    StyledTextInputPopup.nativeChrome = false
  end

  StyledTextInputPopup.nativeChrome = savedNative
end
