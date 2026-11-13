local PublicApiEnv = require("tests.helpers.public_api_env")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")

-- A click on another addon's widget card: its `who` asks the quiet /who
-- first, before the addon's onClick. In game SendWho is blocked once that
-- onClick has run, so a whisper it starts (SendTell) must ask nothing.
-- The real runtime is booted; only WoW APIs and WhoLookup's senders are faked.
local GLOBALS = { "hooksecurefunc", "ChatFrameUtil", "ChatFrame_SendTell" }

local function postHook(target, method, hook)
  if type(target) == "string" then
    target, method, hook = _G, target, method
  end
  local original = target[method]
  rawset(target, method, function(...)
    original(...)
    hook(...)
  end)
end

local function installGame(asks)
  rawset(WhoLookup, "TryFor", function(_runtime, conversationKey)
    asks[#asks + 1] = "key:" .. tostring(conversationKey)
  end)
  rawset(WhoLookup, "TryForName", function(_runtime, playerName)
    asks[#asks + 1] = "name:" .. tostring(playerName)
  end)
  rawset(_G, "hooksecurefunc", postHook)
  rawset(_G, "ChatFrameUtil", { SendTellWithMessage = function() end })
  rawset(_G, "ChatFrame_SendTell", function() end)
end

local function case(label, fn)
  local saved = { tryFor = WhoLookup.TryFor, tryForName = WhoLookup.TryForName }
  for _, key in ipairs(GLOBALS) do
    saved[key] = rawget(_G, key)
  end
  local asks = {}
  installGame(asks)
  local ok, err = pcall(function()
    local runtime, api = PublicApiEnv.Initialize({ autoOpenOutgoing = true })
    runtime.autoOpenCoordinator.installPoller()
    fn(runtime, api, asks)
  end)
  PublicApiEnv.Reset()
  rawset(WhoLookup, "TryFor", saved.tryFor)
  rawset(WhoLookup, "TryForName", saved.tryForName)
  for _, key in ipairs(GLOBALS) do
    rawset(_G, key, saved[key])
  end
  assert(ok, label .. ": " .. tostring(err))
end

local function clickCard(runtime)
  local frame = runtime.icon.previewFrame
  frame:GetScript("OnMouseUp")(frame, "LeftButton")
end

local function rightClickWhisper()
  _G.ChatFrameUtil.SendTellWithMessage("Firstmoon", "", nil)
end

local function sendTell()
  _G.ChatFrame_SendTell("Firstmoon")
end

local function asked(asks)
  return table.concat(asks, ",")
end

return function()
  case("card who asks before the card's onClick", function(runtime, api, asks)
    api.ShowPreview("ca", {
      sender = "Crafter",
      text = "Needs Belt",
      who = "Jaina-Proudmoore",
      onClick = function()
        asks[#asks + 1] = "onClick"
      end,
    })
    clickCard(runtime)
    assert(asked(asks) == "name:Jaina-Proudmoore,onClick", asked(asks))
  end)

  case("right-click Whisper outside a card asks", function(_runtime, _api, asks)
    rightClickWhisper()
    assert(asked(asks) == "name:Firstmoon", asked(asks))
  end)

  case("ChatFrame_SendTell outside a card asks", function(_runtime, _api, asks)
    sendTell()
    assert(#asks == 1 and asks[1]:sub(1, 4) == "key:", asked(asks))
  end)

  case("a card's onClick that right-click whispers asks nothing", function(runtime, api, asks)
    api.ShowPreview("ca", { sender = "Crafter", text = "Needs Belt", onClick = rightClickWhisper })
    clickCard(runtime)
    assert(#asks == 0, asked(asks))
  end)

  case("a card's onClick that calls ChatFrame_SendTell asks nothing", function(runtime, api, asks)
    api.ShowPreview("ca", { sender = "Crafter", text = "Needs Belt", onClick = sendTell })
    clickCard(runtime)
    assert(#asks == 0, asked(asks))
  end)

  case("a card with who whose onClick whispers asks only for who", function(runtime, api, asks)
    api.ShowPreview("ca", { sender = "Crafter", text = "Needs Belt", who = "Jaina-Proudmoore", onClick = rightClickWhisper })
    clickCard(runtime)
    assert(asked(asks) == "name:Jaina-Proudmoore", asked(asks))
  end)

  case("a whisper after a throwing card onClick asks again", function(runtime, api, asks)
    api.ShowPreview("ca", {
      sender = "Crafter",
      text = "Needs Belt",
      onClick = function()
        error("boom")
      end,
    })
    clickCard(runtime)
    rightClickWhisper()
    assert(asked(asks) == "name:Firstmoon", asked(asks))
  end)
end
