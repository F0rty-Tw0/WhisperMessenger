local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ComposerLayout = ns.ComposerLayout or require("WhisperMessenger.UI.Composer.ComposerLayout")
local GlyphCoverage = ns.ThemeGlyphCoverage or require("WhisperMessenger.UI.Theme.GlyphCoverage")
local LineBreaks = ns.ComposerLineBreaks or require("WhisperMessenger.UI.Composer.LineBreaks")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- The composer's text box. WoW: Forever draws no letters in an edit box
-- inside an addon-made scroll frame, so the text scrolls in Blizzard's input
-- scroll frame with its art, character count and scroll bar hidden, held in
-- a plain box frame. A client without that template gets a plain
-- single-line edit box.
local ComposerInputBox = {}

local FALLBACK_INSET_Y = 4

-- The template's scroll frame with its edit box, nil on a client without it.
local function createTemplateScroll(factory, pane)
  local scroll = UIHelpers.createInputScroll(factory, pane)
  if scroll == nil then
    return nil
  end

  UIHelpers.hideTextures(scroll)
  local bar = scroll.ScrollBar
  if bar then
    bar:Hide()
    bar:HookScript("OnShow", bar.Hide)
  end

  return scroll
end

-- The scroll frame scrolls its whole content to keep the cursor in view, so
-- padding and art on it would scroll away past the row cap. The holder keeps
-- them still, and a click on its padding focuses the input as the template's
-- own click does.
local function createHolder(factory, pane, scroll)
  local holder = factory.CreateFrame("Frame", nil, pane)
  holder:Show()
  scroll:SetParent(holder)
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function()
    scroll.EditBox:SetFocus()
  end)

  return holder
end

local function createPlainBox(factory, pane)
  local input = factory.CreateFrame("EditBox", nil, pane)
  if input.SetTextInsets then
    local insetX = ComposerLayout.TEXT_INSET_X
    input:SetTextInsets(insetX, insetX, FALLBACK_INSET_Y, FALLBACK_INSET_Y)
  end

  return input
end

local function setUpInput(input)
  input:SetText("")
  GlyphCoverage.SetInputFont(input, Theme.FONTS.composer_input)
  UIHelpers.setTextColor(input, Theme.COLORS.text_primary)
  if input.SetAutoFocus then
    input:SetAutoFocus(false)
  end
  if input.SetAltArrowKeyMode then
    input:SetAltArrowKeyMode(false)
  end
  if input.SetHyperlinksEnabled then
    input:SetHyperlinksEnabled(true)
  end
end

-- Returns { box, scroll, input, multiLine }: box is the frame to size, place
-- and draw on; scroll is the template's scroll frame inside it. A client
-- without the template has no scroll, and box is the input itself.
function ComposerInputBox.Create(factory, pane)
  local scroll = createTemplateScroll(factory, pane)
  local box, input
  if scroll then
    box, input = createHolder(factory, pane, scroll), scroll.EditBox
  else
    input = createPlainBox(factory, pane)
    box = input
  end
  setUpInput(input)
  local parts = { box = box, scroll = scroll, input = input, multiLine = scroll ~= nil }

  return parts
end

-- Our OnTextChanged runs after the template's own, which keeps its scroll
-- range in step with the text.
function ComposerInputBox.SetTextChanged(input, handler)
  local templateHandler = input:GetScript("OnTextChanged")
  -- SetText fires OnTextChanged again in the game; that echo is ours.
  local flattening = false
  input:SetScript("OnTextChanged", function(self, userInput)
    if flattening then
      return
    end
    local text = self:GetText() or ""
    local cursorAt = #text
    if self.GetCursorPosition then
      cursorAt = self:GetCursorPosition()
    end
    local flat, cursor = LineBreaks.Flatten(text, cursorAt)
    if flat ~= text then
      flattening = true
      self:SetText(flat)
      if self.SetCursorPosition then
        self:SetCursorPosition(cursor)
      end
      flattening = false
    end
    if templateHandler then
      templateHandler(self, userInput)
    end
    handler(self, userInput)
  end)
end

-- Escape first drops an open reply, then (double-escape setting) only leaves
-- the box, else closes the window through onEscape.
function ComposerInputBox.WireEscape(input, replies, getDoubleEscapeToClose, onEscape)
  input:SetScript("OnEscapePressed", function()
    if replies.current() ~= nil then
      replies.clear()
      return
    end
    if getDoubleEscapeToClose and getDoubleEscapeToClose() then
      if input.ClearFocus then
        input:ClearFocus()
      end
      return
    end
    if onEscape then
      onEscape()
      return
    end
    if input.ClearFocus then
      input:ClearFocus()
    end
  end)
end

ns.ComposerInputBox = ComposerInputBox
return ComposerInputBox
