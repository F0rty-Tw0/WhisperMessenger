local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local Flavor = require("tests.helpers.flavor")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Localization = require("WhisperMessenger.Locale.Localization")
local Composer = require("WhisperMessenger.UI.Composer")
local ComposerPadHint = require("WhisperMessenger.UI.Composer.ComposerPadHint")

local CONTACT = { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }

local function pictures(key)
  return "atlas-" .. key
end

local function markup(atlas)
  return "<" .. atlas .. ">"
end

-- A pane with a holder and an input on it; seams default to pad UI on and pictures.
local function rig(seams)
  seams = seams or {}
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetFrameLevel(5)
  local box = factory.CreateFrame("Frame", nil, pane)
  local input = factory.CreateFrame("EditBox", nil, box)
  local padOn = seams.padOn ~= false
  local state = { input = input, pane = pane, box = box }
  if seams.beforeCreate then
    seams.beforeCreate(input)
  end
  state.hint = ComposerPadHint.Create(factory, pane, {
    input = input,
    box = box,
    isPadUIOn = function()
      return padOn
    end,
    buttonAtlas = seams.buttonAtlas or pictures,
    atlasMarkup = seams.atlasMarkup or markup,
  })
  function state.setPadOn(value)
    padOn = value
  end
  return state
end

local function expectedText(a, b)
  return a .. " " .. Localization.Text("Send") .. "   " .. b .. " " .. Localization.Text("Back")
end

local function buildComposer(factory)
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  return Composer.Create(factory, parent, CONTACT, function() end, nil, nil, nil, nil)
end

-- Runs check under every flavor stub, with the gamepad API installed or not.
local function eachFlavor(withApi, check)
  for _, flavor in ipairs(Flavor.ALL) do
    local env = FakeGamepad.New()
    if withApi then
      env.install()
    end
    local ok, err = pcall(Flavor.With, flavor[1], flavor[2], check)
    env.uninstall()
    assert(ok, flavor.name .. ": " .. tostring(err))
  end
end

return function()
  Fonts.Initialize("default")

  -- test_hint_shows_when_the_cursor_enters_with_the_pad_ui_on
  do
    local r = rig()
    r.input:SetFocus()
    assert(r.hint.frame:IsShown(), "the hint shows when the cursor enters with the pad UI on")
  end

  -- test_hint_stays_hidden_when_the_cursor_enters_with_the_pad_ui_off
  do
    local r = rig({ padOn = false })
    r.input:SetFocus()
    assert(not r.hint.frame:IsShown(), "no hint with the pad UI off")
  end

  -- test_hint_hides_when_the_cursor_leaves
  do
    local r = rig()
    r.input:SetFocus()
    r.input:ClearFocus()
    assert(not r.hint.frame:IsShown(), "the hint hides when the cursor leaves")
  end

  -- test_switching_the_pad_ui_off_while_focused_leaves_the_hint_shown
  do
    local r = rig()
    r.input:SetFocus()
    r.setPadOn(false)
    assert(r.hint.frame:IsShown(), "the hint stays until the cursor leaves")
  end

  -- test_switching_the_pad_ui_on_while_focused_leaves_the_hint_hidden
  do
    local r = rig({ padOn = false })
    r.input:SetFocus()
    r.setPadOn(true)
    assert(not r.hint.frame:IsShown(), "no hint until the cursor enters again")
  end

  -- test_hint_text_uses_the_games_pictures
  do
    local r = rig()
    r.input:SetFocus()
    local text = r.hint.label:GetText()
    local want = expectedText("<atlas-PAD1>", "<atlas-PAD2>")
    assert(text == want, "pictures for A and B, got " .. tostring(text))
  end

  -- test_hint_text_falls_back_to_letters
  do
    local r = rig({
      buttonAtlas = function()
        return nil
      end,
    })
    r.input:SetFocus()
    local text = r.hint.label:GetText()
    assert(text == expectedText("A", "B"), "bare letters without pictures, got " .. tostring(text))
  end

  -- test_hint_text_mixes_picture_and_letter
  do
    local r = rig({
      buttonAtlas = function(key)
        if key == "PAD2" then
          return nil
        end
        return pictures(key)
      end,
    })
    r.input:SetFocus()
    local text = r.hint.label:GetText()
    assert(text == expectedText("<atlas-PAD1>", "B"), "a picture for A, a letter for B, got " .. tostring(text))
  end

  -- test_hint_text_falls_back_to_letters_without_the_markup_function
  do
    local r = rig({ atlasMarkup = "not a function" })
    r.input:SetFocus()
    local text = r.hint.label:GetText()
    assert(text == expectedText("A", "B"), "bare letters without CreateAtlasMarkup, got " .. tostring(text))
  end

  -- test_hint_text_falls_back_to_letters_when_the_lookup_throws
  do
    local r = rig({
      buttonAtlas = function()
        error("no icon for this pad")
      end,
    })
    local ok, err = pcall(r.input.SetFocus, r.input)
    assert(ok, "no error reaches the focus handler: " .. tostring(err))
    local text = r.hint.label:GetText()
    assert(text == expectedText("A", "B"), "bare letters when the lookup throws, got " .. tostring(text))
  end

  -- test_hint_text_falls_back_to_letters_when_the_lookup_returns_a_non_string
  do
    local r = rig({
      buttonAtlas = function()
        return 42
      end,
    })
    r.input:SetFocus()
    local text = r.hint.label:GetText()
    assert(text == expectedText("A", "B"), "bare letters for a non-string atlas, got " .. tostring(text))
  end

  -- test_hint_frame_draws_above_the_pane
  do
    local r = rig()
    assert(r.hint.frame:GetFrameLevel() > r.pane:GetFrameLevel(), "the hint frame is raised above the pane")
  end

  -- test_hint_sits_above_the_holders_top_right_corner
  do
    local r = rig()
    local point = r.hint.label.points and r.hint.label.points[1]
    assert(point and point[1] == "BOTTOMRIGHT" and point[2] == r.box and point[3] == "TOPRIGHT", "the label's corner sits on the holder's")
    assert(point[5] > 0, "a gap above the holder")
  end

  -- test_refresh_theme_repaints_the_hint
  do
    local r = rig()
    r.hint.label.textColor = nil
    r.hint.refreshTheme()
    assert(r.hint.label.textColor ~= nil, "refreshTheme applies the label color again")
  end

  -- test_hint_does_not_replace_other_focus_hooks
  do
    local fired = 0
    local r = rig({
      beforeCreate = function(input)
        input:HookScript("OnEditFocusGained", function()
          fired = fired + 1
        end)
      end,
    })
    r.input:SetFocus()
    assert(fired == 1, "a hook added before the hint still fires")
  end

  -- test_composer_has_no_pad_hint_without_the_gamepad_api
  eachFlavor(false, function()
    local composer = buildComposer(FakeUI.NewFactory({ wrap = true }))
    assert(composer.padHint == nil, "no hint without the gamepad API")
  end)

  -- test_composer_has_no_pad_hint_on_a_plain_edit_box
  eachFlavor(true, function()
    local factory = RetailHud.Factory(FakeUI, { missing = { InputScrollFrameTemplate = true } })
    local composer = buildComposer(factory)
    assert(composer.scroll == nil, "the plain edit box has no scroll frame")
    assert(composer.padHint == nil, "no hint on a plain edit box")
  end)

  -- test_composer_has_a_pad_hint_with_the_api_and_the_scroll_frame
  eachFlavor(true, function()
    local composer = buildComposer(FakeUI.NewFactory({ wrap = true }))
    assert(composer.padHint ~= nil and composer.padHint.frame ~= nil, "a hint with the API and the scroll frame")
  end)

  -- test_composer_refresh_theme_repaints_the_hint
  eachFlavor(true, function()
    local composer = buildComposer(FakeUI.NewFactory({ wrap = true }))
    local label = composer.padHint.label
    label:SetTextColor(0, 0, 0, 0)
    composer.refreshTheme()
    local want = Theme.COLORS.text_secondary
    local r, g, b = label:GetTextColor()
    assert(r == want[1] and g == want[2] and b == want[3], "the composer's refreshTheme paints the hint label again")
  end)

  Fonts.Initialize("default")
  print("PASS: test_composer_pad_hint")
end
