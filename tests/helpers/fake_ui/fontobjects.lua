-- Installs _G.CreateFont stub, standard WoW font objects, and _G.C_Timer.
-- Call FontObjects.Install() once per test harness boot.
local FontObjects = {}

function FontObjects.Install()
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
          -- Like the game, the copy takes the source's shadow and colour too.
          self._shadowOffset = source._shadowOffset
          self._shadowColor = source._shadowColor
          self._textColor = source._textColor
        end
      end

      function font:SetTextColor(r, g, b, a)
        self._textColor = { r, g, b, a }
      end

      function font:GetTextColor()
        local c = self._textColor
        if c == nil then
          return nil
        end
        return c[1], c[2], c[3], c[4]
      end

      function font:SetFontObject(source)
        self:CopyFontObject(source)
      end

      function font:SetShadowOffset(x, y)
        self._shadowOffset = { x, y }
      end

      function font:SetShadowColor(r, g, b, a)
        self._shadowColor = { r, g, b, a }
      end

      _G[name] = font
      return font
    end

  -- Stub standard WoW font objects used as sources by Fonts.lua
  local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
  local SYSTEM_FONT = "Fonts\\ARIALN.TTF"
  -- Real WoW FontObjects for tooltip text carry a multi-script FontFamily
  -- chain with CJK fallback fonts. Fake the same shape so tests can assert
  -- that the addon inherits from this object on CJK locales.
  local TOOLTIP_FONT = "Fonts\\TOOLTIP_FAMILY.TTF"
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
    -- Tooltip text FontObject — addons treat this as a known CJK-fallback source
    { "GameTooltipText", TOOLTIP_FONT, 12 },
  }
  -- Colours the game's font objects carry (gold, grey); the rest stay unset.
  local standardColors = {
    GameFontNormal = { 1, 0.82, 0, 1 },
    GameFontDisableSmall = { 0.5, 0.5, 0.5, 1 },
  }
  for _, def in ipairs(standardFonts) do
    local name, path, size = def[1], def[2], def[3]
    if not _G[name] then
      local obj = _G.CreateFont(name)
      obj:SetFont(path, size, "")
      local color = standardColors[name]
      if color then
        obj:SetTextColor(color[1], color[2], color[3], color[4])
      end
    end
  end

  _G.C_Timer = _G.C_Timer or {
    After = function(_seconds, callback)
      if callback then
        callback()
      end
    end,
  }
end

return FontObjects
