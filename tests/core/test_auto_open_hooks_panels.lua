local FakeUI = require("tests.helpers.fake_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local AutoOpenCoordinator = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator")

-- Auto-open hooks wired by the real coordinator onto a real messenger window:
-- a whisper the user starts must land on screen, not under an addon panel.
return function()
  local function build()
    local factory = FakeUI.NewFactory()
    local savedParent = _G.UIParent
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.UIParent:SetSize(1280, 720)
    local window = MessengerWindow.Create(factory, {})
    _G.UIParent = savedParent
    window.frame:Show()
    local panel = { title = "Craft Alert", onShow = function() end, onHide = function() end }
    assert(window.registerPanel("CraftAlert", panel) == true, "panel registers")

    local selected = {}
    local runtime = {
      localProfileId = "me",
      accountState = { settings = { autoOpenIncoming = true, autoOpenOutgoing = true } },
      store = { conversations = {} },
      window = window,
      lastIncomingWhisperKey = "me::WOW::bob-realm",
      ensureWindow = function() end,
      setWindowVisible = function() end,
    }
    AutoOpenCoordinator.Attach({
      runtime = runtime,
      accountState = runtime.accountState,
      isInCombat = function()
        return false
      end,
      windowRuntime = {
        selectConversation = function(conversationKey)
          selected[#selected + 1] = conversationKey
        end,
        isWindowVisible = function()
          return true
        end,
      },
    })
    return runtime.autoOpenHooks, window, selected
  end

  local function assertChatOnScreen(label, window, selected, routed)
    assert(routed == true, label .. ": routed to the messenger")
    assert(#selected == 1, label .. ": selected one conversation, got " .. #selected)
    assert(window.getVisiblePanel() == nil, label .. ": panel closed, got " .. tostring(window.getVisiblePanel()))
    assert(window.isConversationPaneShown() == true, label .. ": chat on screen")
  end

  local function test_send_tell_closes_the_open_panel()
    local hooks, window, selected = build()
    window.showPanel("CraftAlert")
    assertChatOnScreen("send tell", window, selected, hooks.onSendTell("Bob-Realm"))
  end

  local function test_reply_tell_closes_the_open_panel()
    local hooks, window, selected = build()
    window.showPanel("CraftAlert")
    assertChatOnScreen("reply tell", window, selected, hooks.onReplyTell())
  end

  local function test_outgoing_whisper_closes_the_open_panel()
    local hooks, window, selected = build()
    window.showPanel("CraftAlert")
    assertChatOnScreen("outgoing", window, selected, hooks.onOutgoingWhisper("me::WOW::bob-realm"))
  end

  local function test_send_tell_closes_the_options_pane()
    local hooks, window, selected = build()
    window.setOptionsVisible(true)
    assertChatOnScreen("send tell over options", window, selected, hooks.onSendTell("Bob-Realm"))
  end

  local function test_incoming_whisper_leaves_the_open_panel()
    local hooks, window, selected = build()
    window.showPanel("CraftAlert")
    hooks.onIncomingWhisper("me::WOW::bob-realm")
    assert(#selected == 1, "incoming: selects the whisper underneath")
    assert(window.getVisiblePanel() == "CraftAlert", "incoming: panel stays, got " .. tostring(window.getVisiblePanel()))
  end

  test_send_tell_closes_the_open_panel()
  test_reply_tell_closes_the_open_panel()
  test_outgoing_whisper_closes_the_open_panel()
  test_send_tell_closes_the_options_pane()
  test_incoming_whisper_leaves_the_open_panel()
end
