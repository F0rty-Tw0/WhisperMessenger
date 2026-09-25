local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Compact quote at the top of a reply bubble: accent bar, author, dim
-- one-line snippet. Cached on the (pooled) bubble frame.
local ReplyQuote = {}

ReplyQuote.LINE_HEIGHT = 14
ReplyQuote.GAP = 4
-- Space a quote adds to a bubble; the row estimate uses the same number.
ReplyQuote.HEIGHT = ReplyQuote.LINE_HEIGHT + ReplyQuote.GAP
-- Accent bar left of a quote (also the composer's "Replying to" strip).
ReplyQuote.BAR_WIDTH = 2
local BAR_WIDTH = ReplyQuote.BAR_WIDTH
local TEXT_INSET = 6

-- "<heading in accent>  <snippet>", shared with the "Replying to" strip.
function ReplyQuote.FormatLine(heading, snippet)
  return UIHelpers.colorEscape(Theme.COLORS.accent) .. heading .. "|r  " .. (snippet or "")
end

local function onClick(self)
  if type(self._wmOnQuoteClick) == "function" then
    self._wmOnQuoteClick(self._wmReplyTo)
  end
end

local function ensureQuote(factory, frame)
  local quote = frame._wmReplyQuote
  if quote then
    return quote
  end
  quote = factory.CreateFrame("Button", nil, frame)
  local bar = quote:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", quote, "TOPLEFT", 0, 0)
  bar:SetPoint("BOTTOMLEFT", quote, "BOTTOMLEFT", 0, 0)
  bar:SetWidth(BAR_WIDTH)
  local label = quote:CreateFontString(nil, "OVERLAY")
  label:SetPoint("LEFT", quote, "LEFT", TEXT_INSET, 0)
  label:SetJustifyH("LEFT")
  if label.SetWordWrap then
    label:SetWordWrap(false)
  end
  quote._wmBar = bar
  quote._wmLabel = label
  quote:SetScript("OnClick", onClick)
  frame._wmReplyQuote = quote
  return quote
end

function ReplyQuote.Hide(frame)
  if frame._wmReplyQuote then
    frame._wmReplyQuote:Hide()
    frame._wmReplyQuote._wmReplyTo = nil
    frame._wmReplyQuote._wmOnQuoteClick = nil
  end
end

-- Shows the quote at the bubble's inner top-left. Returns the width it needs
-- (0 when the message is not a reply).
function ReplyQuote.Apply(factory, frame, message, maxWidth, padH, padV, onQuoteClick)
  local replyTo = message.replyTo
  if type(replyTo) ~= "table" then
    ReplyQuote.Hide(frame)
    return 0
  end
  local quote = ensureQuote(factory, frame)
  local author = replyTo.author or Localization.Text("You")
  local label = quote._wmLabel
  UIHelpers.setFontObject(label, Theme.FONTS.message_time)
  UIHelpers.setTextColor(label, Theme.COLORS.text_secondary)
  label:SetText(ReplyQuote.FormatLine(author, replyTo.snippet))
  label:Show()
  UIHelpers.applyColorTexture(quote._wmBar, Theme.COLORS.accent)
  quote._wmBar:Show()
  local width = math.min(label:GetStringWidth() + TEXT_INSET, maxWidth)
  label:SetWidth(width - TEXT_INSET)
  quote:ClearAllPoints()
  quote:SetPoint("TOPLEFT", frame, "TOPLEFT", padH, -padV)
  quote:SetSize(width, ReplyQuote.LINE_HEIGHT)
  quote._wmReplyTo = replyTo
  quote._wmOnQuoteClick = onQuoteClick
  quote:Show()
  return width
end

ns.ChatBubbleReplyQuote = ReplyQuote
return ReplyQuote
