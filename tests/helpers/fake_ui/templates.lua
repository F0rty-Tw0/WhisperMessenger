-- Applies Blizzard frame template wiring to a frame.
-- Templates.Apply(frame, template, createFrame) handles all known templates.
local Templates = {}

function Templates.Apply(frame, template, createFrame)
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
  elseif template == "UIPanelButtonTemplate" then
    -- Button widget methods only; the template's child keys are not faked.
    function frame:LockHighlight()
      self.highlightLocked = true
    end
    function frame:UnlockHighlight()
      self.highlightLocked = false
    end
  end
end

return Templates
