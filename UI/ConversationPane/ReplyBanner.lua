local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local CloseGlyphButton = ns.CloseGlyphButton or require("WhisperMessenger.UI.Shared.CloseGlyphButton")
local ReplyQuote = ns.ChatBubbleReplyQuote or require("WhisperMessenger.UI.ChatBubble.ReplyQuote")

-- "Replying to <name>" strip above the composer, in the AFK/DND banner slot:
-- accent bar, name, dim snippet, close button. Lines up with the composer
-- edges. Modern skin closes with the search field's "X", red on hover;
-- Native WoW HUD uses Blizzard's close button.
local ReplyBanner = {}

local HEIGHT = 20
local BAR_WIDTH = ReplyQuote.BAR_WIDTH
local CLOSE_SIZE = 20
local GAP = 6

local function createCloseButton(factory, parent, nativeChrome)
  local native = nativeChrome and UIHelpers.createTemplatedFrame(factory, "Button", nil, parent, "UIPanelCloseButton")
  if native then
    native:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    return native
  end
  return CloseGlyphButton.Create(factory, parent, CLOSE_SIZE, nil, { danger = true })
end

-- options: nativeChrome
function ReplyBanner.Create(factory, pane, options)
  options = options or {}
  local frame = factory.CreateFrame("Frame", nil, pane)
  frame:SetHeight(HEIGHT)
  local gutter = Theme.LAYOUT.COMPOSER_GUTTER
  frame:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", gutter, 2)
  frame:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -gutter, 2)

  local bar = frame:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bar:SetWidth(BAR_WIDTH)

  local close = createCloseButton(factory, frame, options.nativeChrome)
  close:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

  local label = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  label:SetPoint("LEFT", frame, "LEFT", BAR_WIDTH + GAP, 0)
  label:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
  label:SetJustifyH("LEFT")
  if label.SetWordWrap then
    label:SetWordWrap(false)
  end
  frame:Hide()

  local banner = { frame = frame }
  local replyTo
  local onCancel

  local function render()
    UIHelpers.applyColorTexture(bar, Theme.COLORS.accent)
    UIHelpers.applyColor(label, Theme.COLORS.text_secondary)
    if replyTo == nil then
      label:SetText("")
      return
    end
    local name = replyTo.author or Localization.Text("You")
    local heading = string.format(Localization.Text("Replying to %s"), name)
    label:SetText(ReplyQuote.FormatLine(heading, replyTo.snippet))
  end

  close:SetScript("OnClick", function()
    if onCancel then
      onCancel()
    end
  end)

  function banner.setReply(nextReplyTo, nextOnCancel)
    replyTo = nextReplyTo
    onCancel = nextOnCancel
    render()
  end

  function banner.setShown(shown)
    frame:SetShown(shown == true)
  end

  banner.setLanguage = render
  banner.refreshTheme = render

  return banner
end

ns.ConversationPaneReplyBanner = ReplyBanner
return ReplyBanner
