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
end

return FontObjects
