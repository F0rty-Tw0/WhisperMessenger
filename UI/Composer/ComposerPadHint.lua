local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Controller hint above the message box: "<A> Send   <B> Back". It shows
-- when the cursor enters the box with the gamepad UI on and hides when the
-- cursor leaves; nothing else changes it. Focus is hooked, never set: the
-- window hooks the same events.
local ComposerPadHint = {}

-- The chat's edge shadow sits 20 levels above its scroll frame, one level
-- below the composer pane; 30 keeps the hint over it.
local LEVEL_LIFT = 30
local GAP_ABOVE_BOX = Theme.LAYOUT.CONTACT_ACTION_SPACING
-- The label font's height, used when the font can't be read.
local PICTURE_FALLBACK_SIZE = Theme.FONTS.DEFAULT_BASE_SIZE
local WORD_GAP = "   "

local function pictureSize(label)
  local _, height = label:GetFont()

  if type(height) ~= "number" or height <= 0 then
    return PICTURE_FALLBACK_SIZE
  end

  return math.floor(height + 0.5)
end

-- The game's picture for the button, else its bare letter.
local function buttonMark(key, letter, buttonAtlas, atlasMarkup, size)
  if type(atlasMarkup) ~= "function" then
    return letter
  end
  local found, atlas = pcall(buttonAtlas, key)

  if not found or type(atlas) ~= "string" or atlas == "" then
    return letter
  end
  local made, markup = pcall(atlasMarkup, atlas, size, size)

  if made and type(markup) == "string" then
    return markup
  end

  return letter
end

-- parts: input (EditBox), box (holder to sit above); test seams isPadUIOn,
-- buttonAtlas, atlasMarkup default to the game's.
function ComposerPadHint.Create(factory, pane, parts)
  local input, box = parts.input, parts.box
  local isPadUIOn = parts.isPadUIOn or FlavorCompat.IsGamepadUIEnabled
  local buttonAtlas = parts.buttonAtlas or FlavorCompat.GamepadButtonAtlas
  local atlasMarkup = parts.atlasMarkup or _G["CreateAtlasMarkup"]

  local frame = factory.CreateFrame("Frame", nil, pane)
  frame:SetAllPoints(pane)
  frame:SetFrameLevel(pane:GetFrameLevel() + LEVEL_LIFT)
  frame:Hide()

  local label = frame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(label, Theme.FONTS.icon_label)
  UIHelpers.setTextColor(label, Theme.COLORS.text_secondary)
  label:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, GAP_ABOVE_BOX)

  local function hintText()
    local size = pictureSize(label)
    local a = buttonMark(_G["GAMEPAD_FACE_BOTTOM"] or "PAD1", "A", buttonAtlas, atlasMarkup, size)
    local b = buttonMark(_G["GAMEPAD_FACE_RIGHT"] or "PAD2", "B", buttonAtlas, atlasMarkup, size)

    return a .. " " .. Localization.Text("Send") .. WORD_GAP .. b .. " " .. Localization.Text("Back")
  end

  local function onFocusGained()
    local padUIOn = isPadUIOn()

    if not padUIOn then
      return
    end
    label:SetText(hintText())
    frame:Show()
  end

  local function refreshTheme()
    UIHelpers.setTextColor(label, Theme.COLORS.text_secondary)
  end

  input:HookScript("OnEditFocusGained", onFocusGained)
  input:HookScript("OnEditFocusLost", function()
    frame:Hide()
  end)

  local hint = { frame = frame, label = label, refreshTheme = refreshTheme }

  return hint
end

ns.ComposerPadHint = ComposerPadHint
return ComposerPadHint
