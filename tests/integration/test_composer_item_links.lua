local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local savedHooksecurefunc = _G.hooksecurefunc
  local registeredHooks = {}

  _G.hooksecurefunc = function(name, handler)
    registeredHooks[name] = handler
  end

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    if frameType == "EditBox" then
      local originalSetText = frame.SetText
      frame._textValue = ""
      frame._hasFocus = false

      frame.SetText = function(self, value)
        originalSetText(self, value)
        self._textValue = value
      end

      frame.GetText = function(self)
        return self._textValue
      end

      frame.HasFocus = function(self)
        return self._hasFocus == true
      end

      frame.SetFocus = function(self)
        self._hasFocus = true
      end

      frame.ClearFocus = function(self)
        self._hasFocus = false
      end

      frame.Insert = function(self, text)
        self:SetText((self:GetText() or "") .. text)
      end
    end
    return frame
  end

  local parent = factory.CreateFrame("Frame", "ComposerParent", nil)
  parent:SetSize(600, 200)

  local composer = Composer.Create(factory, parent, {
    conversationKey = "me::WOW::arthas-area52",
    displayName = "Arthas-Area52",
    channel = "WOW",
  }, function()
  end)

  assert(registeredHooks.HandleModifiedItemClick ~= nil, "expected composer to register a HandleModifiedItemClick hook")

  composer.frame:Show()
  composer.input:Show()
  composer.input:SetFocus()
  registeredHooks.HandleModifiedItemClick("|cff0070dd|Hitem:19019::::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r")

  assert(
    composer.input:GetText() == "|cff0070dd|Hitem:19019::::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r",
    "expected focused composer input to receive the item link"
  )

  _G.hooksecurefunc = savedHooksecurefunc
end
