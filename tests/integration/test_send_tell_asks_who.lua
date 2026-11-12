local FakeUI = require("tests.helpers.fake_ui")

-- Right-click Whisper (ChatFrameUtil.SendTellWithMessage) asks the quiet /who
-- inside the click; a typed "/w Name " never asks. The right-click chat opens a frame later through C_Timer, so its /who goes out by name
-- before the chat exists, and the answer must still land on that chat.
-- The real runtime is booted; only WoW APIs are faked.
local GLOBALS = { "C_Timer", "C_FriendList", "ChatFrameUtil", "hooksecurefunc", "GetTime", "time", "ChatFrame1EditBox", "NUM_CHAT_WINDOWS" }

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 2) ~= "##" and not trimmed:match("%.xml$") then
      local chunk = assert(loadfile(trimmed))
      chunk(addonName, ns)
    end
  end
end

local function postHook(target, method, hook)
  if type(target) == "string" then
    target, method, hook = _G, target, method
  end
  local original = target[method]
  target[method] = function(...)
    original(...)
    hook(...)
  end
end

local function installGame(env)
  env.timers, env.sent, env.whoResults = {}, {}, {}
  rawset(_G, "C_Timer", {
    After = function(_seconds, fn)
      env.timers[#env.timers + 1] = fn
    end,
    NewTimer = function(_seconds, fn)
      return { callback = fn, Cancel = function() end }
    end,
  })
  rawset(_G, "C_FriendList", {
    SendWho = function(filter)
      env.sent[#env.sent + 1] = { filter = filter, chatExisted = env.chatExists() }
    end,
    SetWhoToUi = function() end,
    GetNumWhoResults = function()
      return #env.whoResults
    end,
    GetWhoInfo = function(i)
      return env.whoResults[i]
    end,
  })
  rawset(_G, "hooksecurefunc", postHook)
  rawset(_G, "GetTime", function()
    return 1000
  end)
  rawset(_G, "time", os.time)
  rawset(_G, "NUM_CHAT_WINDOWS", 1)
end

-- The game's right-click Whisper: opens (focuses) the chat box first, then
-- aims it, so the focus hook still sees the old chat type.
local function installChatBox(env, factory)
  local box = factory.CreateFrame("EditBox", "ChatFrame1EditBox", nil)
  local attributes = { chatType = "SAY", stickyType = "SAY" }
  function box:GetAttribute(key)
    return attributes[key]
  end
  function box:SetAttribute(key, value)
    attributes[key] = value
  end
  rawset(_G, "ChatFrame1EditBox", box)
  rawset(_G, "ChatFrameUtil", {
    SendTellWithMessage = function(name, _text, _chatFrame)
      box:SetFocus()
      attributes.chatType = "WHISPER"
      attributes.tellTarget = name
    end,
  })
  env.box = box
end

local function boot(opts)
  local env = { saved = {} }
  for _, key in ipairs(GLOBALS) do
    env.saved[key] = rawget(_G, key)
  end
  installGame(env)
  local factory = FakeUI.NewFactory()
  installChatBox(env, factory)
  local settings = {
    showPlayerLevels = opts.showPlayerLevels ~= false,
    whoLookups = opts.whoLookups,
    autoOpenOutgoing = opts.autoOpenOutgoing ~= false,
  }
  local accountState = { conversations = {}, contacts = {}, pendingHydration = {}, schemaVersion = 1, settings = settings }
  local characterState = {
    window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 920, height = 580, minimized = false },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
  }
  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  _G.UISpecialFrames = {}
  local runtime = ns.Bootstrap.Initialize(factory, { accountState = accountState, characterState = characterState, localProfileId = "current" })
  ns.Bootstrap.runtime = runtime
  runtime.autoOpenCoordinator.installPoller()
  if opts.competitive then
    runtime.isCompetitiveContent = function()
      return true
    end
  end
  env.ns, env.runtime = ns, runtime
  env.key = ns.Identity.BuildConversationKey("current", "WOW::firstmoon")
  env.chatExists = function()
    return ns.ConversationStore.Find(runtime.store, env.key) ~= nil
  end
  return env
end

local function drainTimers(env)
  local drained = 0
  while #env.timers > 0 and drained < 50 do
    table.remove(env.timers, 1)()
    drained = drained + 1
  end
end

local function case(label, opts, fn)
  local env = boot(opts or {})
  local ok, err = pcall(fn, env)
  env.ns.DisplayName.Configure({ showPlayerLevels = false })
  for _, key in ipairs(GLOBALS) do
    rawset(_G, key, env.saved[key])
  end
  assert(ok, label .. ": " .. tostring(err))
end

local function rightClickWhisper()
  _G.ChatFrameUtil.SendTellWithMessage("Firstmoon", "", nil)
end

local function typeSlashWhisper(env)
  env.box:SetText("/w Firstmoon ")
  env.box._hookScripts.OnTextChanged[1](env.box, true)
end

local function fireWhoListUpdate(env)
  local frame = env.ns.SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, "WHO_LIST_UPDATE")
end

return function()
  case("right-click asks inside the click, before the chat exists", nil, function(env)
    rightClickWhisper()
    assert(#env.sent == 1 and env.sent[1].filter == 'n-"Firstmoon"', "asked " .. #env.sent)
    assert(env.sent[1].chatExisted == false, "the /who goes out before the deferred open")
    drainTimers(env)
    assert(env.runtime.activeConversationKey == env.key, "the deferred open selects the new chat")
  end)

  case("right-click's deferred open does not ask again", nil, function(env)
    local asks = 0
    local tryFor, tryForName = env.ns.WhoLookup.TryFor, env.ns.WhoLookup.TryForName
    env.ns.WhoLookup.TryFor = function(...)
      asks = asks + 1
      return tryFor(...)
    end
    env.ns.WhoLookup.TryForName = function(...)
      asks = asks + 1
      return tryForName(...)
    end
    rightClickWhisper()
    drainTimers(env)
    env.ns.WhoLookup.TryFor, env.ns.WhoLookup.TryForName = tryFor, tryForName
    assert(asks == 1, "asked " .. asks)
  end)

  case("right-click's /who answer lands on the chat the open created", nil, function(env)
    env.whoResults = { { fullName = "Firstmoon", level = 75, area = "Dornogal" } }
    rightClickWhisper()
    drainTimers(env)
    fireWhoListUpdate(env)
    local conversation = env.ns.ConversationStore.Find(env.runtime.store, env.key)
    assert(conversation.characterLevel == 75, "level " .. tostring(conversation.characterLevel))
    assert(env.ns.SeenZone.Get("Firstmoon") == "Dornogal", "zone " .. tostring(env.ns.SeenZone.Get("Firstmoon")))
  end)

  -- The game does not count OnTextChanged as a hardware event for SendWho:
  -- asking there raised ADDON_ACTION_BLOCKED in game (2026-11-11).
  case("typed slash whisper opens the chat without asking", nil, function(env)
    typeSlashWhisper(env)
    assert(#env.sent == 0, "asked " .. #env.sent)
    assert(env.runtime.activeConversationKey == env.key, "WM opens the chat")
  end)

  case("right-click WM does not open asks nothing", { autoOpenOutgoing = false }, function(env)
    rightClickWhisper()
    drainTimers(env)
    assert(#env.sent == 0, "asked " .. #env.sent)
  end)

  case("typed slash whisper WM does not open asks nothing", { autoOpenOutgoing = false }, function(env)
    typeSlashWhisper(env)
    assert(#env.sent == 0, "asked " .. #env.sent)
  end)

  case("right-click in competitive content asks nothing", { competitive = true }, function(env)
    rightClickWhisper()
    drainTimers(env)
    assert(#env.sent == 0, "asked " .. #env.sent)
  end)

  case("right-click with player levels off still asks", { showPlayerLevels = false }, function(env)
    rightClickWhisper()
    assert(#env.sent == 1 and env.sent[1].filter == 'n-"Firstmoon"', "asked " .. #env.sent)
  end)

  case("right-click with /who lookups off asks nothing", { whoLookups = false }, function(env)
    rightClickWhisper()
    drainTimers(env)
    assert(#env.sent == 0, "asked " .. #env.sent)
  end)

  case("typed slash whisper with /who lookups off asks nothing", { whoLookups = false }, function(env)
    typeSlashWhisper(env)
    assert(#env.sent == 0, "asked " .. #env.sent)
  end)
end
