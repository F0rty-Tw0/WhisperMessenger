local FakeUI = require("tests.helpers.fake_ui")
local WindowScripts = require("WhisperMessenger.UI.MessengerWindow.WindowScripts")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local function noop() end

  -- -----------------------------------------------------------------------
  -- test_tab_switching_shows_correct_panel
  -- -----------------------------------------------------------------------
  do
    local generalPanel = factory.CreateFrame("Frame", nil, parent)
    local appearancePanel = factory.CreateFrame("Frame", nil, parent)
    local behaviorPanel = factory.CreateFrame("Frame", nil, parent)
    local notificationsPanel = factory.CreateFrame("Frame", nil, parent)

    -- Give each tab a bg texture child (for highlight logic)
    local function makeTab()
      local tab = factory.CreateFrame("Frame", nil, parent)
      local bg = tab:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(tab)
      bg:SetColorTexture(0.14, 0.15, 0.20, 0.80)
      return tab
    end

    local generalTab = makeTab()
    local appearanceTab = makeTab()
    local behaviorTab = makeTab()
    local notificationsTab = makeTab()

    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
      settingsTabs = { generalTab, appearanceTab, behaviorTab, notificationsTab },
      settingsPanels = { generalPanel, appearancePanel, behaviorPanel, notificationsPanel },
    }

    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    _G.StaticPopup_Show = function() end

    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    -- Default: first panel (General) shown, others hidden
    assert(generalPanel.shown == true, "generalPanel should be shown by default")
    assert(appearancePanel.shown == false, "appearancePanel should be hidden by default")
    assert(behaviorPanel.shown == false, "behaviorPanel should be hidden by default")
    assert(notificationsPanel.shown == false, "notificationsPanel should be hidden by default")

    -- Click Appearance tab
    appearanceTab.scripts.OnClick(appearanceTab)
    assert(generalPanel.shown == false, "generalPanel should be hidden after clicking appearance")
    assert(appearancePanel.shown == true, "appearancePanel should be shown after clicking appearance")
    assert(behaviorPanel.shown == false, "behaviorPanel should stay hidden")
    assert(notificationsPanel.shown == false, "notificationsPanel should stay hidden")

    -- Click Behavior tab
    behaviorTab.scripts.OnClick(behaviorTab)
    assert(appearancePanel.shown == false, "appearancePanel should be hidden after clicking behavior")
    assert(behaviorPanel.shown == true, "behaviorPanel should be shown after clicking behavior")

    -- Click Notifications tab
    notificationsTab.scripts.OnClick(notificationsTab)
    assert(behaviorPanel.shown == false, "behaviorPanel should be hidden after clicking notifications")
    assert(notificationsPanel.shown == true, "notificationsPanel should be shown after clicking notifications")

    -- Click General tab again
    generalTab.scripts.OnClick(generalTab)
    assert(notificationsPanel.shown == false, "notificationsPanel should be hidden after clicking general")
    assert(generalPanel.shown == true, "generalPanel should be shown after clicking general")

    _G.StaticPopupDialogs = nil
    _G.StaticPopup_Show = nil
  end
end
