-- The world MenuPopup draws into: a fake UIParent, CreateFrame and
-- UISpecialFrames. With(fn) runs fn(factory, anchor), anchor being a shown
-- Button under UIParent, then closes the popup and restores every global,
-- even when fn fails.
local FakeUI = require("tests.helpers.fake_ui")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")

local MenuPopupWorld = {}

local SAVED_NAMES = { "UIParent", "CreateFrame", "UISpecialFrames" }

function MenuPopupWorld.With(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  rawset(_G, "CreateFrame", factory.CreateFrame)
  rawset(_G, "UIParent", factory.CreateFrame("Frame", "UIParent", nil))
  rawset(_G, "UISpecialFrames", {})
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  anchor:Show()

  local ok, err = pcall(fn, factory, anchor)
  MenuPopup.Close()
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  if not ok then
    error(err, 0)
  end
end

return MenuPopupWorld
