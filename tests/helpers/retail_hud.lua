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
