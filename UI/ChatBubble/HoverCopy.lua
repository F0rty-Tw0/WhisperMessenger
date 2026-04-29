local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local HoverCopy = {}

local COPY_BUTTON_SIZE = 14
-- Inside the bubble's top corner. The HIGH strata below keeps the button on
-- top of the sender name + time text strip above the bubble even when the
-- bubble is short and the name extends past the bubble's far edge.
local COPY_BUTTON_EDGE_INSET = 5
local COPY_BUTTON_TOP_OFFSET = 7
local COPY_BUTTON_DIM_ALPHA = 0.45
local COPY_BUTTON_TEXTURE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"

local function isMouseOver(region)
  if region == nil or type(region.IsMouseOver) ~= "function" then
    return false
  end
  local ok, value = pcall(region.IsMouseOver, region)
  if ok then
    return value == true
  end
  return false
end

local function ensureCopyButton(persistentFactory, frame)
  local button = frame._copyButton
  if button then
    return button
  end
  if type(persistentFactory) ~= "table" or type(persistentFactory.CreateFrame) ~= "function" then
    return nil
  end

  -- Must NOT come from the pooled factory: the FramePool reuses arbitrary
  -- frames by ignoring requested frameType and parent, which would hijack a
  -- recycled avatar/label and drop a non-Button (no OnClick) into our slot.
  --
  -- Parent the button to the bubble's PARENT (contentFrame), not the bubble
  -- itself. As a sibling of the bubble, the button shares the bubble's draw
  -- stratum directly — no parent-strata cap can demote it, and a higher
  -- frame level than any bubble guarantees it always renders on top, even
  -- when neighbouring bubbles overlap its top edge (grouped messages) or
  -- the messenger window flips strata on click.
  local buttonParent = (type(frame.GetParent) == "function" and frame:GetParent()) or frame
  button = persistentFactory.CreateFrame("Button", nil, buttonParent)
  button._wmCopyButton = true
  button:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
  if button.EnableMouse then
    button:EnableMouse(true)
  end

  local tex = button:CreateTexture(nil, "OVERLAY")
  if tex.SetAllPoints then
    tex:SetAllPoints(button)
  end
  if tex.SetTexture then
    tex:SetTexture(COPY_BUTTON_TEXTURE)
  end
  if tex.SetVertexColor then
    tex:SetVertexColor(1, 1, 1, 1)
  end
  button._copyTexture = tex

  if button.SetAlpha then
    button:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  if button.Hide then
    button:Hide()
  end

  if button.SetScript then
    button:SetScript("OnEnter", function(self)
      if self.SetAlpha then
        self:SetAlpha(1)
      end
      local tip = _G.GameTooltip
      if type(tip) == "table" and type(tip.SetOwner) == "function" and type(tip.SetText) == "function" then
        tip:SetOwner(self, "ANCHOR_TOP")
        tip:SetText("Copy text")
        if type(tip.Show) == "function" then
          tip:Show()
        end
      end
    end)
    button:SetScript("OnLeave", function(self)
      if self.SetAlpha then
        self:SetAlpha(COPY_BUTTON_DIM_ALPHA)
      end
      local tip = _G.GameTooltip
      if type(tip) == "table" and type(tip.Hide) == "function" then
        -- Only dismiss the tooltip if it still belongs to us. The bubble's
        -- OnHyperlinkEnter may have re-anchored it to show an item / spell
        -- tooltip while the cursor moved across the corner — hiding it
        -- here would make linked-item tooltips disappear under custom
        -- fonts where text wraps closer to the button.
        local owner = type(tip.GetOwner) == "function" and tip:GetOwner() or nil
        if owner == nil or owner == self then
          tip:Hide()
        end
      end
      -- The user moved off the button; if they're not on the bubble either,
      -- hide. Mirrors the bubble's own OnLeave guard so the button doesn't
      -- linger after the cursor has fully left the bubble area.
      if not isMouseOver(frame) then
        self:Hide()
      end
    end)
  end

  frame._copyButton = button
  return button
end

function HoverCopy.Attach(persistentFactory, frame, message, copyText)
  local button = ensureCopyButton(persistentFactory, frame)
  if button == nil then
    return
  end
  button:ClearAllPoints()
  if message.direction == "out" then
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", COPY_BUTTON_EDGE_INSET, COPY_BUTTON_TOP_OFFSET)
  else
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -COPY_BUTTON_EDGE_INSET, COPY_BUTTON_TOP_OFFSET)
  end
  -- Re-assert z-order on EVERY render. The messenger window flips its strata
  -- between MEDIUM and HIGH on click (see WindowScripts/Frame/ScriptBindings),
  -- and pool reuse means a recycled bubble frame may carry a stale level from
  -- a previous role. Setting strata + level + Raise here keeps the icon on
  -- top regardless of how the surrounding frame stack drifted.
  if button.SetFrameStrata then
    button:SetFrameStrata("HIGH")
  end
  if button.SetFrameLevel and frame.GetFrameLevel then
    local lvl = frame:GetFrameLevel() or 1
    button:SetFrameLevel(lvl + 10)
  end
  if button.Raise then
    button:Raise()
  end
  if button.SetAlpha then
    button:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  if button.Hide then
    button:Hide()
  end

  if button.SetScript then
    button:SetScript("OnClick", function()
      local text = message.text
      if type(text) ~= "string" or text == "" then
        return
      end
      copyText(text)
    end)
  end

  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      if button.Show then
        button:Show()
      end
    end)
    frame:SetScript("OnLeave", function()
      if isMouseOver(button) then
        return
      end
      if button.Hide then
        button:Hide()
      end
    end)
    -- The button is now a sibling of the bubble, not a child — so hiding
    -- the bubble (e.g. via FramePool.releaseAll) no longer auto-hides the
    -- button. Wire OnHide so the button always disappears with its bubble.
    frame:SetScript("OnHide", function()
      if button.Hide then
        button:Hide()
      end
    end)
  end
end

ns.ChatBubbleHoverCopy = HoverCopy
return HoverCopy
