local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local Flavor = require("tests.helpers.flavor")
local ContactsContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

-- Like the live client, SetScript drops the hooks HookScript added before it.
local function withLiveSetScript(factory)
  local create = factory.CreateFrame
  factory.CreateFrame = function(...)
    local frame = create(...)
    local setScript = frame.SetScript
    frame.SetScript = function(self, eventName, handler)
      if self._hookScripts then
        self._hookScripts[eventName] = nil
      end
      return setScript(self, eventName, handler)
    end
    return frame
  end
  return factory
end

local function build()
  local factory = withLiveSetScript(FakeUI.NewFactory())
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local window = MessengerWindow.Create(factory, {})
  _G.UIParent = savedUIParent
  return window
end

-- Runs fn(env) on the given flavor with the fake gamepad UI installed;
-- withoutApi: on a client that has no gamepad UI.
local function onFlavor(isRetail, isForever, fn, withoutApi)
  local env = FakeGamepad.New()
  env.install(withoutApi)
  local ok, err = pcall(Flavor.With, isRetail, isForever, function()
    fn(env)
  end)
  env.uninstall()
  assert(ok, err)
end

return function()
  -- test_game_right_click_on_the_header_opens_the_chat_menu
  onFlavor(false, true, function(env)
    local window = build()
    window.frame:Show()
    local view = window.conversation
    local contact = { displayName = "Arthas", channel = "WOW" }
    view._selectedContact = contact
    local opened, original = {}, ContactsContextMenu.Open
    rawset(ContactsContextMenu, "Open", function(target, anchor)
      opened[#opened + 1] = { target = target, anchor = anchor }
      return true
    end)
    local ok, err = pcall(env.rightClick, view.headerFrame)
    rawset(ContactsContextMenu, "Open", original)
    assert(ok, err)
    assert(#opened == 1 and opened[1].target == contact and opened[1].anchor == view.headerFrame, "same menu as a mouse right-click")
  end)

  -- test_header_without_the_api_has_no_binding
  onFlavor(true, false, function(env)
    local window = build()
    window.frame:Show()
    assert(env.pressX(window.conversation.headerFrame) == false and #env.calls == 0, "no gamepad UI: unchanged")
  end, true)

  -- test_retail_window_with_the_api_leaves_x_unbound
  onFlavor(true, false, function(env)
    local window = build()
    window.frame:Show()
    assert(env.count("FrameShown") == 1, "the API alone registers the window, whatever the flavor")
    assert(#env.bindings == 0 and #env.footers == 0, "no prompted binding or footer from the game's utility")
    assert(env.pressX(window.conversation.headerFrame) == false, "X does nothing on the header")
  end)
end
