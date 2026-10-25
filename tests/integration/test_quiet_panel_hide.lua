local FakeUI = require("tests.helpers.fake_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ChatCover = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.ChatCover")
local Panels = require("WhisperMessenger.Core.PublicApi.Panels")
local PublicApi = require("WhisperMessenger.Core.PublicApi")
local PreviewOpen = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewOpen")

-- A real window (real WindowVisibility) with panel "ca" and a covered chat
-- "me::WOW::arthas"; `selected` logs every chat selection.
local function build()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local selected = {}
  local runtime = { activeConversationKey = "me::WOW::arthas" }
  local window
  runtime.isWindowVisible = function()
    return window.frame:IsShown()
  end
  runtime.setWindowVisible = function(visible)
    if visible then
      window.frame:Show()
    else
      window.frame:Hide()
    end
  end
  runtime.ensureWindow = function() end
  runtime.isCompetitiveContent = function()
    return false
  end
  runtime.isMythicLockdown = function()
    return false
  end
  local spec = { title = "ca", onShow = function() end, onHide = function() end }
  runtime.panelRegistry = {
    get = function(key)
      return key == "ca" and spec or nil
    end,
    register = function()
      return true
    end,
  }
  runtime.startConversation = function(name)
    selected[#selected + 1] = "start:" .. name
    return true
  end
  runtime.setComposerText = function() end
  window = MessengerWindow.Create(factory, {
    onConversationUncovered = ChatCover.OnUncovered({
      runtime = runtime,
      isWindowVisible = runtime.isWindowVisible,
      selectConversation = function(key)
        selected[#selected + 1] = key
      end,
    }),
  })
  _G.UIParent = savedUIParent
  runtime.window = window
  window.frame:Show()
  assert(window.registerPanel("ca", spec) == true)
  return runtime, window, selected
end

local function buildPreviewOpen(runtime, selected)
  return PreviewOpen.Create({
    runtime = runtime,
    buildContacts = function()
      return {}
    end,
    buildLatestIncomingPreview = function()
      return { conversationKey = "me::WOW::jaina" }
    end,
    selectConversation = function(key)
      selected[#selected + 1] = "preview:" .. key
    end,
  })
end

return function()
  local function test_toggle_panel_closing_does_not_select_the_covered_chat()
    local runtime, window, selected = build()
    local api = {}
    Panels.Install(api, runtime)
    assert(api.ShowPanel("ca") == true)
    assert(api.TogglePanel("ca") == true)
    assert(window.frame:IsShown() == false, "the window closes")
    assert(#selected == 0, "covered chat selected: " .. table.concat(selected, ","))
  end

  local function test_open_conversation_from_a_shown_panel_selects_only_the_new_chat()
    local runtime, _, selected = build()
    local api = PublicApi.Build(runtime)
    Panels.Install(api, runtime)
    assert(api.ShowPanel("ca") == true)
    assert(api.OpenConversation("Jaina") == true)
    assert(table.concat(selected, ",") == "start:Jaina", "selections: " .. table.concat(selected, ","))
  end

  local function test_preview_open_from_a_shown_panel_selects_only_the_preview_chat()
    local runtime, window, selected = build()
    window.showPanel("ca")
    buildPreviewOpen(runtime, selected)()
    assert(table.concat(selected, ",") == "preview:me::WOW::jaina", "selections: " .. table.concat(selected, ","))
  end

  local function test_preview_open_with_settings_open_shows_the_chat()
    local runtime, window, selected = build()
    window.optionsButton:GetScript("OnClick")(window.optionsButton)
    assert(window.isConversationPaneShown() == false, "settings cover the chat")
    buildPreviewOpen(runtime, selected)()
    assert(window.isConversationPaneShown() == true, "the opened chat is on screen")
    assert(table.concat(selected, ",") == "preview:me::WOW::jaina", "selections: " .. table.concat(selected, ","))
  end

  test_toggle_panel_closing_does_not_select_the_covered_chat()
  test_open_conversation_from_a_shown_panel_selects_only_the_new_chat()
  test_preview_open_from_a_shown_panel_selects_only_the_preview_chat()
  test_preview_open_with_settings_open_shows_the_chat()
end
