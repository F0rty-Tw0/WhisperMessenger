local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

-- Player links in our window are shown encoded as addon links, so Blizzard's
-- click handler on the link template leaves them to us. A shift-clicked name
-- must still reach the composer, and the server, as the plain name: nothing
-- encoded may ever be sent, and the stored message keeps the raw link.

local PLAYER_LINK = "|Hplayer:Name-Realm:12|h[Name]|h"
local ENCODED_PREFIX = "addon:WhisperMessenger:player:"

local SAVED_GLOBALS = {
  "CreateFrame",
  "SlashCmdList",
  "SLASH_WHISPERMESSENGER1",
  "SLASH_WHISPERMESSENGER2",
  "C_ChatInfo",
  "C_XMLUtil",
  "UnitFullName",
  "GetNormalizedRealmName",
  "InCombatLockdown",
  "hooksecurefunc",
  "SetItemRef",
  "IsModifiedClick",
  "GetTime",
}

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

-- Post-hooks like the real hooksecurefunc: the original runs first, then ours.
local function postHook(target, method, hook)
  local container, key = _G, target
  if type(target) == "table" then
    container, key = target, method
  else
    hook = method
  end
  local original = rawget(container, key)
  if type(original) ~= "function" then
    error("hooksecurefunc: " .. tostring(key) .. " is not a function")
  end
  rawset(container, key, function(...)
    local result = original(...)
    hook(...)
    return result
  end)
end

local function installGlobals(sendCalls, createdFrames, factory)
  rawset(_G, "UnitFullName", function()
    return "Arthas", "Area52"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "C_XMLUtil", {
    GetTemplateInfo = function()
      return { type = "Frame" }
    end,
  })
  rawset(_G, "hooksecurefunc", postHook)
  rawset(_G, "SetItemRef", function() end)
  rawset(_G, "IsModifiedClick", function(action)
    return action == "CHATLINK"
  end)
  rawset(_G, "GetTime", function()
    return 100
  end)
  rawset(_G, "SlashCmdList", {})
  rawset(_G, "SLASH_WHISPERMESSENGER1", nil)
  rawset(_G, "SLASH_WHISPERMESSENGER2", nil)
  rawset(_G, "C_ChatInfo", {
    SendChatMessage = function(message, chatType, _, target)
      table.insert(sendCalls, { message = message, chatType = chatType, target = target })
    end,
  })
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local frame = factory.CreateFrame(frameType, name, parent, template)
    table.insert(createdFrames, frame)
    function frame:RegisterEvent(eventName)
      self.events = self.events or {}
      self.events[eventName] = true
    end
    function frame:UnregisterEvent(eventName)
      if self.events then
        self.events[eventName] = nil
      end
    end
    return frame
  end)
end

local function findEventFrame(createdFrames)
  for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
      return frame
    end
  end
  error("expected addon load event frame")
end

local function findLinkBubble(window)
  local bubble = FindUI.find(window.frame, function(node)
    return node._textFS ~= nil and type(node._textFS.text) == "string" and string.find(node._textFS.text, "|H", 1, true) ~= nil
  end)
  assert(bubble ~= nil, "expected a bubble showing the player link")
  return bubble
end

-- Game frames start shown; FakeUI frames start hidden until Show().
local function showWithAncestors(frame)
  while frame ~= nil do
    if type(frame.Show) == "function" then
      frame:Show()
    end
    frame = frame.parent
  end
end

-- Template click script (Blizzard's SetItemRef path), then our post-hooks.
local function shiftClickLink(frame, link, text)
  assert(type(frame.templateHyperlinkClick) == "function", "bubble frame has the link template")
  frame.templateHyperlinkClick(frame, link, text, "LeftButton")
  for _, hook in ipairs((frame._hookScripts or {}).OnHyperlinkClick or {}) do
    hook(frame, link, text, "LeftButton")
  end
end

local function storedIncomingText(runtime)
  for _, conversation in pairs(runtime.store.conversations) do
    for _, message in ipairs(conversation.messages or {}) do
      if message.direction == "in" then
        return message.text
      end
    end
  end
  return nil
end

local function test_shift_clicked_player_name_sends_plain()
  local createdFrames, sendCalls = {}, {}
  installGlobals(sendCalls, createdFrames, FakeUI.NewFactory())

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  local eventFrame = findEventFrame(createdFrames)
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  local runtime = ns.Bootstrap.runtime
  local whisperText = "ask " .. PLAYER_LINK .. " about it"
  local onEvent = eventFrame.scripts.OnEvent
  onEvent(eventFrame, "CHAT_MSG_WHISPER", whisperText, "Arthas-Area52", "", "", "", "", "", "", "", "", 101, "Player-3676-0ABCDEF0")

  runtime.toggle()
  assert(runtime.window ~= nil, "expected window after toggle")
  runtime.window.contacts.rows[1].scripts.OnClick()

  local input = runtime.window.composer.input
  showWithAncestors(input)
  input:SetText("")
  input:SetFocus()

  local bubble = findLinkBubble(runtime.window)
  local shown = bubble._textFS.text
  local encodedLink = string.match(shown, "|H(" .. ENCODED_PREFIX .. "[^|]+)|h")
  assert(encodedLink ~= nil, "bubble shows the player link encoded, got " .. tostring(shown))
  local encodedText = "|H" .. encodedLink .. "|h[Name]|h"

  shiftClickLink(bubble, encodedLink, encodedText)
  input.scripts.OnEnterPressed(input)

  assert(#sendCalls == 1, "expected one sent message, got " .. #sendCalls)
  local sent = sendCalls[1].message
  assert(sent == "Name-Realm", "sent the plain name, got " .. tostring(sent))
  assert(string.find(sent, ENCODED_PREFIX, 1, true) == nil, "nothing encoded is sent")

  local stored = storedIncomingText(runtime)
  local keepsRaw = stored ~= nil and string.find(stored, "|Hplayer:Name-Realm:12|h", 1, true) ~= nil
  assert(keepsRaw, "stored message keeps the raw link, got " .. tostring(stored))
end

return function()
  local saved = {}
  for _, key in ipairs(SAVED_GLOBALS) do
    saved[key] = rawget(_G, key)
  end
  local ok, err = pcall(test_shift_clicked_player_name_sends_plain)
  for _, key in ipairs(SAVED_GLOBALS) do
    rawset(_G, key, saved[key])
  end
  if not ok then
    error(err, 0)
  end
end
