local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

-- Open at saved spot is on by default for new installs and anyone who never
-- chose; a saved choice stands.

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
  -- test_a_new_install_opens_at_the_saved_spot
  do
    local runtime = boot(nil)
    assert(runtime.accountState.settings.openAtSavedSpot == true, "got " .. tostring(runtime.accountState.settings.openAtSavedSpot))
  end

  -- test_an_update_without_a_choice_opens_at_the_saved_spot
  do
    local runtime = boot(savedAccount({ showGroupChats = true }))
    assert(runtime.accountState.settings.openAtSavedSpot == true, "got " .. tostring(runtime.accountState.settings.openAtSavedSpot))
  end

  -- test_a_saved_off_choice_stands
  do
    local runtime = boot(savedAccount({ openAtSavedSpot = false }))
    assert(runtime.accountState.settings.openAtSavedSpot == false, "the player's own choice stands")
  end
end
