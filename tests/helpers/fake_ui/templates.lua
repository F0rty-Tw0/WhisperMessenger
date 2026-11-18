-- Applies Blizzard frame template wiring to a frame.
-- Templates.Apply(frame, template, createFrame) handles all known templates,
-- applying each name of a comma-separated list in order like the live client.
local Templates = {}

local function applyOne(frame, template, createFrame)
  if template == "BasicFrameTemplateWithInset" then
    frame.Bg = createFrame("Texture", nil, frame, nil)
    frame.Inset = createFrame("Frame", nil, frame, nil)
    frame.NineSlice = createFrame("Frame", nil, frame, nil)
    frame.CloseButton = createFrame("Button", nil, frame, nil)
    frame.TitleContainer = createFrame("Frame", nil, frame, nil)
    frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString(nil, "OVERLAY")
    frame.TitleText = frame.TitleContainer.TitleText

    function frame:SetTitle(text)
      self.title = text
      if self.TitleContainer and self.TitleContainer.TitleText then
        self.TitleContainer.TitleText:SetText(text)
      end
    end
  elseif template == "ButtonFrameTemplate" then
    -- Only the child keys probed on a live Retail client (2026-10-02). The
    -- live mixin methods (SetTitle, SetPortraitToAsset) were not probed, so
    -- they are not faked; tests add them when they need them.
    frame.Bg = createFrame("Texture", nil, frame, nil)
    frame.Inset = createFrame("Frame", nil, frame, nil)
    frame.NineSlice = createFrame("Frame", nil, frame, nil)
    frame.TitleContainer = createFrame("Frame", nil, frame, nil)
    frame.TopTileStreaks = createFrame("Texture", nil, frame, nil)
    frame.PortraitContainer = createFrame("Frame", nil, frame, nil)
    frame.PortraitContainer.portrait = frame.PortraitContainer:CreateTexture(nil, "OVERLAY")
    frame.PortraitContainer.CircleMask = frame.PortraitContainer:CreateTexture(nil, "OVERLAY")
    frame.CloseButton = createFrame("Button", nil, frame, nil)
  elseif template == "SearchBoxTemplate" then
    -- Assumed live child keys (verify in-game): Instructions, clearButton, searchIcon.
    frame.Instructions = frame:CreateFontString(nil, "ARTWORK")
    frame.clearButton = createFrame("Button", nil, frame, nil)
    frame.searchIcon = frame:CreateTexture(nil, "OVERLAY")
  elseif template == "SecureActionButtonTemplate" then
    -- The template's own OnClick runs the secure action, and the template
    -- makes the button protected. frame.secureClicks counts that handler.
    frame.secureClicks = 0
    frame:SetScript("OnClick", function(self)
      self.secureClicks = self.secureClicks + 1
    end)
    function frame:IsProtected()
      return true, true
    end
  elseif template == "InputScrollFrameTemplate" then
    -- EditBox and CharCount seen on a live WoW: Forever client (2026-11-08).
    -- The template's own OnTextChanged keeps its scroll range in step with
    -- the text; frame.EditBox.templateTextChanges counts that handler.
    frame.EditBox = createFrame("EditBox", nil, frame, nil)
    frame.EditBox.templateTextChanges = 0
    frame.EditBox:SetScript("OnTextChanged", function(self)
      self.templateTextChanges = self.templateTextChanges + 1
    end)
    frame.CharCount = frame:CreateFontString(nil, "OVERLAY")
    frame.CharCount:Show()
    -- Border textures (TopTex, MiddleTex, ...) and a Frame ScrollBar with
    -- Track, Back and Forward, probed on WoW: Forever (2026-11-08). The
    -- Track.Thumb button and the art inside each part are assumed.
    frame.TopTex = frame:CreateTexture(nil, "BACKGROUND")
    frame.TopTex:Show()
    local function shownChild(frameType, parent)
      local child = createFrame(frameType, nil, parent, nil)
      child:Show()
      child.Art = child:CreateTexture(nil, "ARTWORK")
      child.Art:Show()
      return child
    end
    local bar = shownChild("Frame", frame)
    bar.Back = shownChild("Button", bar)
    bar.Forward = shownChild("Button", bar)
    bar.Track = shownChild("Frame", bar)
    bar.Track.Thumb = shownChild("Button", bar.Track)
    frame.ScrollBar = bar
  elseif template == "UIPanelButtonTemplate" then
    -- Button widget methods only; the template's child keys are not faked.
    function frame:LockHighlight()
      self.highlightLocked = true
    end
    function frame:UnlockHighlight()
      self.highlightLocked = false
    end
  elseif template == "InlineHyperlinkFrameTemplate" then
    -- The template's own OnHyperlinkClick runs Blizzard code that calls
    -- SetItemRef; frame.templateHyperlinkClick keeps that handler.
    frame.templateHyperlinkClick = function(_self, link, text, button)
      _G.SetItemRef(link, text, button)
    end
    frame:SetScript("OnHyperlinkClick", frame.templateHyperlinkClick)
    -- Its hover scripts show the raw link in GameTooltip, with no decode
    -- of our encoded links and no trade-link block.
    frame.templateHyperlinkEnter = function(_self, link)
      local tooltip = _G.GameTooltip
      if tooltip and tooltip.SetHyperlink then
        tooltip:SetHyperlink(link)
      end
    end
    frame.templateHyperlinkLeave = function()
      local tooltip = _G.GameTooltip
      if tooltip and tooltip.Hide then
        tooltip:Hide()
      end
    end
    frame:SetScript("OnHyperlinkEnter", frame.templateHyperlinkEnter)
    frame:SetScript("OnHyperlinkLeave", frame.templateHyperlinkLeave)
  end
end

function Templates.Apply(frame, template, createFrame)
  if type(template) ~= "string" then
    return
  end
  for name in string.gmatch(template, "[^,]+") do
    applyOne(frame, (string.gsub(name, "^%s*(.-)%s*$", "%1")), createFrame)
  end
end

return Templates
