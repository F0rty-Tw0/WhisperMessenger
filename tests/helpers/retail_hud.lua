-- Runs a test body with the Retail Native WoW HUD configured against a
-- stubbed C_XMLUtil, then restores the stub and turns the HUD off again.
local Hud = require("WhisperMessenger.UI.Theme.Hud")

local RetailHud = {}

function RetailHud.With(fn)
  local saved = rawget(_G, "C_XMLUtil")
  rawset(_G, "C_XMLUtil", {
    GetTemplateInfo = function()
      return { type = "Frame" }
    end,
  })
  Hud.Configure("retail")
  local ok, err = pcall(fn)
  rawset(_G, "C_XMLUtil", saved)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

local PANEL_ATLASES = {
  ["Professions-background-summarylist"] = true,
  ["auctionhouse-background-index"] = true,
}

-- Runs a test body with a stubbed C_Texture that knows only the panel
-- background atlases (when `known`), so other atlas lookups (the retail
-- scrollbar width) keep their fallback. Restores the stub afterwards.
function RetailHud.WithAtlas(known, fn)
  local saved = rawget(_G, "C_Texture")
  rawset(_G, "C_Texture", {
    GetAtlasInfo = function(atlas)
      if known and PANEL_ATLASES[atlas] then
        return { width = 300, height = 505 }
      end
      return nil
    end,
  })
  local ok, err = pcall(fn)
  rawset(_G, "C_Texture", saved)
  if not ok then
    error(err, 0)
  end
end

-- A fake factory shaped like a particular client. options:
--   missing  : set of template names whose CreateFrame throws, like the live
--              client does for a template it does not ship
--   decorate : function(frame, template) run on every created frame
function RetailHud.Factory(FakeUI, options)
  local missing = options.missing or {}
  local decorate = options.decorate
  local factory = FakeUI.NewFactory()
  local create = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    if template and missing[template] then
      error("Couldn't find inherited node: " .. template)
    end
    local frame = create(frameType, name, parent, template)
    if decorate then
      decorate(frame, template)
    end
    return frame
  end
  return factory
end

-- Makes `frame`'s new textures lack SetAtlas, like a client that can't draw
-- atlases. Returns the frame.
function RetailHud.WithoutAtlas(frame)
  local createTexture = frame.CreateTexture
  rawset(frame, "CreateTexture", function(self, ...)
    local texture = createTexture(self, ...)
    texture.SetAtlas = nil
    return texture
  end)
  return frame
end

return RetailHud
