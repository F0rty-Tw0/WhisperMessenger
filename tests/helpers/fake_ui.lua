table.unpack = table.unpack or unpack

local FakeUI = {}

function FakeUI.NewFactory()
  local factory = {}

  local function createFrame(frameType, name, parent, template)
    local frame = {
      frameType = frameType,
      name = name,
      parent = parent,
      template = template,
      children = {},
      shown = false,
      alpha = 1,
      mouseOver = false,
      _hasFocus = false,
    }

    if parent then
      table.insert(parent.children, frame)
    end

    function frame:SetSize(width, height)
      self.width = width
      self.height = height
    end

    function frame:GetSize()
      return self.width or 0, self.height or 0
    end

    function frame:SetWidth(width)
      self.width = width
    end

    function frame:SetHeight(height)
      self.height = height
    end

    function frame:SetPoint(...)
      self.point = { ... }
    end

    function frame:GetPoint()
      if self.point == nil then
        return nil
      end

      return table.unpack(self.point)
    end

    function frame:ClearAllPoints()
      self.point = nil
    end

    function frame:SetAllPoints(target)
      self.allPoints = target
    end

    function frame:SetText(text)
      self.text = text
    end

    function frame:GetText()
      return self.text
    end

    function frame:SetMultiLine(value)
      self.multiline = value
    end

    function frame:SetAutoFocus(value)
      self.autoFocus = value
    end

    function frame:SetHyperlinksEnabled(value)
      self.hyperlinksEnabled = value
    end

    function frame:SetFontObject(value)
      self.fontObject = value
    end

    function frame:GetStringHeight()
      local text = tostring(self.text or "")
      local _, lineCount = string.gsub(text, "\n", "\n")
      local effectiveLines = math.max(1, lineCount + 1)
      local lineHeight = self.lineHeight or 16

      return effectiveLines * lineHeight
    end

    function frame:Show()
      self.shown = true
      if self.scripts and self.scripts.OnShow then
        self.scripts.OnShow(self)
      end
    end

    function frame:Hide()
      self.shown = false
      if self.scripts and self.scripts.OnHide then
        self.scripts.OnHide(self)
      end
    end

    function frame:IsShown()
      return self.shown == true
    end

    function frame:IsVisible()
      if not self.shown then
        return false
      end
      if self.parent and type(self.parent.IsVisible) == "function" then
        return self.parent:IsVisible()
      end
      return true
    end

    function frame:SetShown(value)
      if value then
        self:Show()
      else
        self:Hide()
      end
    end

    function frame:SetScript(eventName, handler)
      self.scripts = self.scripts or {}
      self.scripts[eventName] = handler
    end

    function frame:GetScript(eventName)
      if self.scripts == nil then
        return nil
      end

      return self.scripts[eventName]
    end

    function frame:SetAlpha(value)
      self.alpha = value
    end

    function frame:GetAlpha()
      return self.alpha
    end

    function frame:IsMouseOver()
      return self.mouseOver == true
    end

    function frame:HasFocus()
      return self._hasFocus == true
    end

    function frame:SetFocus()
      self._hasFocus = true
      if self.scripts and self.scripts.OnEditFocusGained then
        self.scripts.OnEditFocusGained(self)
      end
    end

    function frame:ClearFocus()
      self._hasFocus = false
      if self.scripts and self.scripts.OnEditFocusLost then
        self.scripts.OnEditFocusLost(self)
      end
    end

    function frame:SetScrollChild(child)
      self.scrollChild = child
    end

    function frame:UpdateScrollChildRect()
      self.scrollChildRectUpdated = true
    end

    function frame:GetVerticalScrollRange()
      local child = self.scrollChild
      local childHeight = 0
      local selfHeight = self.height or 0

      if child ~= nil then
        if type(child.GetHeight) == "function" then
          childHeight = child:GetHeight() or 0
        elseif type(child.height) == "number" then
          childHeight = child.height
        end
      end

      local range = childHeight - selfHeight
      if range < 0 then
        return 0
      end

      return range
    end

    function frame:SetVerticalScroll(offset)
      local range = self:GetVerticalScrollRange()
      local clamped = offset or 0

      if clamped < 0 then
        clamped = 0
      elseif clamped > range then
        clamped = range
      end

      self.verticalScroll = clamped
      if self.scripts and self.scripts.OnVerticalScroll then
        self.scripts.OnVerticalScroll(self, clamped)
      end
    end

    function frame:GetVerticalScroll()
      return self.verticalScroll or 0
    end

    function frame:EnableMouseWheel(value)
      self.mouseWheelEnabled = value
    end

    function frame:SetMinMaxValues(minimum, maximum)
      self.minValue = minimum
      self.maxValue = maximum
    end

    function frame:GetMinMaxValues()
      return self.minValue or 0, self.maxValue or 0
    end

    function frame:SetValueStep(step)
      self.valueStep = step
    end

    function frame:SetOrientation(value)
      self.orientation = value
    end

    function frame:SetThumbTexture(texture)
      self.thumbTexture = texture
    end

    function frame:SetObeyStepOnDrag(value)
      self.obeyStepOnDrag = value
    end

    function frame:SetValue(value)
      self.value = value
      if self.scripts and self.scripts.OnValueChanged then
        self.scripts.OnValueChanged(self, value)
      end
    end

    function frame:GetValue()
      return self.value or 0
    end

    function frame:SetJustifyH(value)
      self.justifyH = value
    end

    function frame:SetJustifyV(value)
      self.justifyV = value
    end

    function frame:SetWordWrap(value)
      self.wordWrap = value
    end

    function frame:SetMaxLines(value)
      self.maxLines = value
    end

    function frame:CreateFontString(childName, layer, inheritedTemplate)
      return createFrame("FontString", childName or (self.name or "frame") .. "Text", self, inheritedTemplate)
    end

    function frame:SetTextColor(...)
      self.textColor = { ... }
    end

    function frame:SetTextInsets(left, right, top, bottom)
      self.textInsets = { left, right, top, bottom }
    end

    function frame:Insert(text)
      self.text = (self.text or "") .. (text or "")
    end

    function frame:GetName()
      return self.name
    end

    function frame:GetWidth()
      return self.width or 0
    end

    function frame:GetHeight()
      return self.height or 0
    end

    function frame:CreateTexture(childName, layer, inheritedTemplate)
      local texture = createFrame("Texture", childName or (self.name or "frame") .. "Texture", self, inheritedTemplate)

      function texture:SetColorTexture(...)
        self.color = { ... }
      end

      function texture:SetTexture(path)
        self.texturePath = path
      end

      function texture:SetVertexColor(...)
        self.vertexColor = { ... }
      end

      function texture:SetDesaturated(value)
        self.desaturated = value
      end

      function texture:SetTexCoord(...)
        self.texCoords = { ... }
      end

      function texture:SetMask(mask)
        self.mask = mask
      end

      function texture:SetAtlas(atlas)
        self.atlas = atlas
      end

      function texture:SetBlendMode(mode)
        self.blendMode = mode
      end

      return texture
    end

    function frame:SetMovable(value)
      self.movable = value
    end

    function frame:IsMovable()
      return self.movable == true
    end

    function frame:StartMoving()
      self.startedMoving = true
      self.moving = true
    end

    function frame:StopMovingOrSizing()
      self.stoppedMoving = true
      self.moving = false
      self.sizing = false
    end

    function frame:StartSizing(anchor)
      self.sizingAnchor = anchor
      self.sizing = true
    end

    function frame:SetFrameStrata(strata)
      self.frameStrata = strata
    end

    function frame:GetFrameLevel()
      return self.frameLevel or 1
    end

    function frame:SetFrameLevel(level)
      self.frameLevel = level
    end

    function frame:EnableMouse(value)
      self.mouseEnabled = value
    end

    function frame:RegisterForDrag(...)
      self.dragButtons = { ... }
    end

    function frame:SetResizable(value)
      self.resizable = value
    end

    function frame:SetMinResize(width, height)
      self.minResize = { width, height }
    end

    function frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
      self.resizeBounds = { minWidth, minHeight, maxWidth, maxHeight }
    end

    function frame:GetRegions()
      local regions = {}
      for _, child in ipairs(self.children) do
        if child.frameType == "Texture" or child.frameType == "FontString" then
          table.insert(regions, child)
        end
      end
      return table.unpack(regions)
    end

    function frame:GetChildren()
      local frames = {}
      for _, child in ipairs(self.children) do
        if child.frameType ~= "Texture" and child.frameType ~= "FontString" then
          table.insert(frames, child)
        end
      end
      return table.unpack(frames)
    end

    function frame:GetStringWidth()
      local text = tostring(self.text or "")
      return #text * 7
    end

    function frame:SetClipsChildren(value)
      self.clipsChildren = value
    end

    function frame:SetClampedToScreen(value)
      self.clamped = value
    end

    function frame:SetNormalFontObject(value)
      self.normalFontObject = value
    end

    function frame:SetHighlightFontObject(value)
      self.highlightFontObject = value
    end

    function frame:SetEnabled(value)
      self.enabled = value
    end

    return frame
  end

  factory.CreateFrame = createFrame
  return factory
end

-- CreateFont stub for font object creation
_G.CreateFont = _G.CreateFont
  or function(name)
    local font = {
      name = name,
      _font = nil,
      _size = 0,
      _flags = "",
    }

    function font:SetFont(path, size, flags)
      self._font = path
      self._size = size or 0
      self._flags = flags or ""
    end

    function font:GetFont()
      return self._font, self._size, self._flags
    end

    function font:CopyFontObject(source)
      if type(source) == "string" then
        source = _G[source]
      end
      if source and source.GetFont then
        local path, size, flags = source:GetFont()
        self._font = path
        self._size = size
        self._flags = flags
      end
    end

    function font:SetFontObject(source)
      self:CopyFontObject(source)
    end

    _G[name] = font
    return font
  end

-- Stub standard WoW font objects used as sources by Fonts.lua
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local SYSTEM_FONT = "Fonts\\ARIALN.TTF"
local standardFonts = {
  -- GameFont family (Friz Quadrata / locale equivalent)
  { "GameFontNormal", DEFAULT_FONT, 12 },
  { "GameFontDisableSmall", DEFAULT_FONT, 10 },
  { "GameFontHighlight", DEFAULT_FONT, 12 },
  { "GameFontHighlightSmall", DEFAULT_FONT, 10 },
  { "GameFontHighlightLarge", DEFAULT_FONT, 16 },
  { "ChatFontNormal", SYSTEM_FONT, 14 },
  -- SystemFont family (Arial Narrow / locale equivalent)
  { "SystemFont_Small", SYSTEM_FONT, 10 },
  { "SystemFont_Med1", SYSTEM_FONT, 12 },
  { "SystemFont_Med3", SYSTEM_FONT, 14 },
  { "SystemFont_Large", SYSTEM_FONT, 16 },
}
for _, def in ipairs(standardFonts) do
  local name, path, size = def[1], def[2], def[3]
  if not _G[name] then
    local obj = _G.CreateFont(name)
    obj:SetFont(path, size, "")
  end
end

_G.C_Timer = _G.C_Timer
  or {
    After = function(_seconds, callback)
      if callback then
        callback()
      end
    end,
  }

return FakeUI
