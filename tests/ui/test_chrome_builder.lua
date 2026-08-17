local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

local function assertTooltipLifecycle(Localization, button, expectedTitle, label)
  local onEnterScript = button.GetScript and button:GetScript("OnEnter") or nil
  local onLeaveScript = button.GetScript and button:GetScript("OnLeave") or nil
  assert(type(onEnterScript) == "function", label .. ": expected OnEnter script")
  assert(type(onLeaveScript) == "function", label .. ": expected OnLeave script")

  local originalGameTooltip = _G.GameTooltip
  local originalLanguage = Localization.GetConfiguredLanguage()
  local tooltipState = { shown = false, hidden = false }
  _G.GameTooltip = {
    SetOwner = function(_, owner, anchor)
      tooltipState.owner = owner
      tooltipState.anchor = anchor
    end,
    SetText = function(_, text)
      tooltipState.text = text
    end,
    AddLine = function(_, text)
      tooltipState.line = text
    end,
    Show = function()
      tooltipState.shown = true
    end,
    Hide = function()
      tooltipState.hidden = true
    end,
  }

  local ok, err = pcall(function()
    Localization.Configure({ language = "enUS" })
    onEnterScript(button)
    assert(tooltipState.text == expectedTitle, label .. ": expected tooltip title " .. expectedTitle .. ", got " .. tostring(tooltipState.text))
    assert(tooltipState.shown == true, label .. ": expected tooltip shown on enter")

    onLeaveScript(button)
    assert(tooltipState.hidden == true, label .. ": expected tooltip hidden on leave")
  end)

  _G.GameTooltip = originalGameTooltip
  Localization.Configure({ language = originalLanguage })
  if not ok then
    error(err, 0)
  end
end

return function()
  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)

  local Localization = ns.Localization
  local ChromeBuilder = ns.MessengerWindowChromeBuilder
  local Theme = ns.Theme

  -- Modern chrome: useNativeChrome=false (or unset) gives BackdropTemplate
  -- + custom title FontString + custom close button.

  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      useNativeChrome = false,
    })

    assert(chrome.frame.template == "BackdropTemplate", "modern chrome: expected BackdropTemplate, got " .. tostring(chrome.frame.template))
    assert(chrome.frame.Inset == nil, "modern chrome: should NOT have template Inset")
    assert(chrome.frame.CloseButton == nil, "modern chrome: should NOT have template CloseButton")
    assert(chrome.title ~= nil, "modern chrome: custom title FontString should exist")
    assert(chrome.title.text == Theme.TITLE, "modern chrome: title should render Theme.TITLE")
    assert(chrome.background ~= nil, "modern chrome: custom background texture should exist")
    assert(chrome.closeButton ~= nil, "modern chrome: custom close button should exist")
    assert(
      chrome.closeButton.frameType == "Button",
      "modern chrome: closeButton should be a Button frame, got " .. tostring(chrome.closeButton.frameType)
    )
  end

  -- Blizzard chrome: useNativeChrome=true gives BasicFrameTemplateWithInset
  -- (gold border, red X, dark inset, centered title from the template).

  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      useNativeChrome = true,
    })

    assert(
      chrome.frame.template == "BasicFrameTemplateWithInset",
      "blizzard chrome: expected BasicFrameTemplateWithInset, got " .. tostring(chrome.frame.template)
    )
    assert(chrome.frame.Bg ~= nil, "blizzard chrome: template should provide frame.Bg")
    assert(chrome.frame.Inset ~= nil, "blizzard chrome: template should provide frame.Inset")
    assert(chrome.frame.CloseButton ~= nil, "blizzard chrome: template should provide frame.CloseButton")
    assert(chrome.frame.TitleText ~= nil, "blizzard chrome: template should provide frame.TitleText")
    assert(chrome.frame.title == Theme.TITLE, "blizzard chrome: SetTitle should set frame.title")

    assert(chrome.background == chrome.frame.Bg, "blizzard chrome: chrome.background aliases frame.Bg")
    assert(chrome.title == chrome.frame.TitleText, "blizzard chrome: chrome.title aliases frame.TitleText")
    assert(chrome.closeButton == chrome.frame.CloseButton, "blizzard chrome: chrome.closeButton aliases frame.CloseButton")
  end

  -- Default (no useNativeChrome flag) should be modern chrome.

  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {})
    assert(
      chrome.frame.template == "BackdropTemplate",
      "default chrome: expected BackdropTemplate when useNativeChrome unset, got " .. tostring(chrome.frame.template)
    )
  end

  -- Options, close, and Back controls expose localized tooltips in both chrome paths.

  do
    for _, case in ipairs({
      { name = "modern chrome", useNativeChrome = false },
      { name = "native chrome", useNativeChrome = true },
    }) do
      local factory = FakeUI.NewFactory()
      local parent = factory.CreateFrame("Frame", "UIParent", nil)
      local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
        useNativeChrome = case.useNativeChrome,
      })

      assertTooltipLifecycle(Localization, chrome.optionsButton, "Options", case.name .. " options button")
      assertTooltipLifecycle(Localization, chrome.closeButton, "Close", case.name .. " close button")
      assertTooltipLifecycle(Localization, chrome.backButton, "Back", case.name .. " Back button")
    end
  end

  -- Shared overlays exist in both chrome paths (newConversation + tooltip).

  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      useNativeChrome = false,
    })

    assert(chrome.newConversationButton ~= nil, "expected a New Conversation button in both chromes")
    local onEnterScript = chrome.newConversationButton.GetScript and chrome.newConversationButton:GetScript("OnEnter") or nil
    local onLeaveScript = chrome.newConversationButton.GetScript and chrome.newConversationButton:GetScript("OnLeave") or nil
    assert(type(onEnterScript) == "function", "expected New Conversation button OnEnter script")
    assert(type(onLeaveScript) == "function", "expected New Conversation button OnLeave script")

    local originalGameTooltip = _G.GameTooltip
    local tooltipState = { shown = false, hidden = false }
    _G.GameTooltip = {
      SetOwner = function(_, owner, anchor)
        tooltipState.owner = owner
        tooltipState.anchor = anchor
      end,
      SetText = function(_, text)
        tooltipState.text = text
      end,
      AddLine = function(_, text)
        tooltipState.line = text
      end,
      Show = function()
        tooltipState.shown = true
      end,
      Hide = function()
        tooltipState.hidden = true
      end,
    }

    onEnterScript(chrome.newConversationButton)
    assert(tooltipState.text == "Start New Whisper", "expected tooltip title text on hover")
    assert(tooltipState.shown == true, "expected tooltip to be shown on hover")

    onLeaveScript(chrome.newConversationButton)
    assert(tooltipState.hidden == true, "expected tooltip to hide on leave")
    _G.GameTooltip = originalGameTooltip

    Localization.Configure({ language = "ruRU" })
    tooltipState = { shown = false, hidden = false }
    _G.GameTooltip = {
      SetOwner = function(_, owner, anchor)
        tooltipState.owner = owner
        tooltipState.anchor = anchor
      end,
      SetText = function(_, text)
        tooltipState.text = text
      end,
      AddLine = function(_, text)
        tooltipState.line = text
      end,
      Show = function()
        tooltipState.shown = true
      end,
      Hide = function()
        tooltipState.hidden = true
      end,
    }
    onEnterScript(chrome.newConversationButton)
    assert(tooltipState.text == "Начать новый шепот", "expected localized new whisper tooltip title")
    assert(tooltipState.line == "Открыть пустую переписку.", "expected localized new whisper tooltip line")
    _G.GameTooltip = originalGameTooltip
    Localization.Configure({ language = "enUS" })

    assert(chrome.frame.frameStrata == "MEDIUM", "expected window frame strata to be MEDIUM")

    local chrome2 = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      title = "Custom",
      useNativeChrome = false,
    })
    if chrome2.title.text then
      assert(chrome2.title.text == "Custom", "expected explicit title override to work in modern chrome")
    end
  end

  -- applyTheme runs cleanly across preset switches in both chromes.

  do
    local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      useNativeChrome = false,
    })

    if Theme.SetPreset then
      Theme.SetPreset("plumber_warm")
      chrome.applyTheme(Theme)
      Theme.SetPreset("elvui_dark")
      chrome.applyTheme(Theme)
      Theme.SetPreset("wow_native")
      chrome.applyTheme(Theme)
      Theme.SetPreset("wow_default")
      chrome.applyTheme(Theme)
    end

    if previousPreset and Theme.SetPreset then
      Theme.SetPreset(previousPreset)
    end
  end
end
