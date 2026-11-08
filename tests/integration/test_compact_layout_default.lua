local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

-- New installs start on the compact window; players updating the addon keep the
-- classic window until they ask for the other one.

local function boot(accountState)
  local factory = FakeUI.NewFactory()
  local saved = { uiParent = _G.UIParent, slash = _G.SlashCmdList }
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  _G.SlashCmdList = {}
  local ok, runtime = pcall(Bootstrap.Initialize, factory, { localProfileId = "me", accountState = accountState })
  _G.UIParent = saved.uiParent
  _G.SlashCmdList = saved.slash
  assert(ok, runtime)
  return runtime
end

local function savedAccount(settings)
  return { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = settings }
end

return function()
  -- test_a_new_install_gets_the_regular_window
  do
    local runtime = boot(nil)
    assert(runtime.accountState.settings.compactLayout == false, "compact is opt-in; saved so the value is explicit")
  end

  -- test_a_new_install_keeps_the_regular_window_on_the_next_login
  do
    local first = boot(nil)
    local second = boot(first.accountState)
    assert(second.accountState.settings.compactLayout == false, "got " .. tostring(second.accountState.settings.compactLayout))
  end

  -- test_an_update_keeps_the_classic_window
  do
    local runtime = boot(savedAccount({ fontSize = 14 }))
    assert(runtime.accountState.settings.compactLayout == false, "got " .. tostring(runtime.accountState.settings.compactLayout))
  end

  -- test_an_update_with_only_saved_chats_keeps_the_classic_window
  do
    local account = savedAccount(nil)
    account.conversations["wow::WOW::arthas-area52"] = { displayName = "Arthas", channel = "WOW", messages = {} }
    local runtime = boot(account)
    assert(runtime.accountState.settings.compactLayout == false, "got " .. tostring(runtime.accountState.settings.compactLayout))
  end

  -- test_a_saved_choice_is_kept
  for _, choice in ipairs({ true, false }) do
    local runtime = boot(savedAccount({ compactLayout = choice }))
    assert(runtime.accountState.settings.compactLayout == choice, "the player's own choice stands")
  end
end
