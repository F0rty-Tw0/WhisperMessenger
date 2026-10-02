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

    function frame:GetTitle()
      return self.title
    end
  elseif template == "SearchBoxTemplate" then
    -- Assumed live child keys (verify in-game): Instructions, clearButton, searchIcon.
    frame.Instructions = frame:CreateFontString(nil, "ARTWORK")
    frame.clearButton = createFrame("Button", nil, frame, nil)
    frame.searchIcon = frame:CreateTexture(nil, "OVERLAY")
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
