local FontFamilies = require("WhisperMessenger.UI.Theme.FontFamilies")

local function withSharedMedia(fonts, fn)
  local savedLibStub = rawget(_G, "LibStub")
  local lsm = {
    List = function()
      local names = {}
      for name in pairs(fonts) do
        names[#names + 1] = name
      end
      return names
    end,
    Fetch = function(_, _mediaType, name)
      return fonts[name]
    end,
  }
  rawset(
    _G,
    "LibStub",
    setmetatable({}, {
      __call = function(_, name)
        if name == "LibSharedMedia-3.0" then
          return lsm
        end
      end,
    })
  )
  local ok, err = pcall(fn)
  rawset(_G, "LibStub", savedLibStub)
  assert(ok, err)
end

return function()
  -- test_fetch_path_returns_the_registered_font_path
  withSharedMedia({ Expressway = "Fonts\\Expressway.ttf" }, function()
    assert(FontFamilies.FetchPath("Expressway") == "Fonts\\Expressway.ttf", "registered font resolves to its path")
  end)

  -- test_fetch_path_ignores_built_in_family_names
  withSharedMedia({ default = "Fonts\\X.ttf" }, function()
    assert(FontFamilies.FetchPath("default") == nil, "default never resolves through LibSharedMedia")
  end)

  -- test_fetch_path_without_libstub_returns_nil
  do
    local savedLibStub = rawget(_G, "LibStub")
    rawset(_G, "LibStub", nil)
    local path = FontFamilies.FetchPath("Expressway")
    rawset(_G, "LibStub", savedLibStub)
    assert(path == nil, "no LibStub means no shared fonts")
  end

  -- test_list_puts_default_first_then_sorts_case_insensitively
  withSharedMedia({ zeta = "z.ttf", Alpha = "a.ttf", morpheus = "m.ttf" }, function()
    local families = FontFamilies.List()
    assert(#families == 3, "default plus two shared fonts, got " .. #families)
    assert(families[1].key == "default", "default first")
    assert(families[2].key == "Alpha", "Alpha second, got " .. tostring(families[2].key))
    assert(families[3].key == "zeta", "zeta third, got " .. tostring(families[3].key))
  end)
end
