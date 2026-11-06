local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

-- Boot sets up party-free group chats: the prefix, the service on the
-- runtime, a row for every joined group and the "/wmsg group" command.
return function()
  local savedTheme = package.loaded["UI.Theme"]
  local savedFonts = package.loaded["UI.Theme.Fonts"]
  local savedWindowRuntime = package.loaded["Core.Bootstrap.WindowRuntime"]
  local savedUIParent = _G.UIParent
  local savedChatInfo = _G.C_ChatInfo
  local savedSlashCmdList = _G.SlashCmdList

  package.loaded["UI.Theme"] = {
    DEFAULT_PRESET = "wow_default",
    ResolvePreset = function(key)
      return key, true
    end,
  }
  package.loaded["UI.Theme.Fonts"] = {
    Initialize = function() end,
    SetFontSize = function() end,
    SetOutline = function() end,
    SetFontColor = function() end,
    SetLanguage = function() end,
  }
  local selected = {}
  package.loaded["Core.Bootstrap.WindowRuntime"] = {
    Create = function()
      return {
        getIcon = function()
          return nil
        end,
        getWindow = function()
          return nil
        end,
        isWindowVisible = function()
          return false
        end,
        selectConversation = function(key)
          selected[#selected + 1] = key
        end,
      }
    end,
  }

  local registered = {}
  _G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
      registered[prefix] = true
      return true
    end,
    SendAddonMessage = function()
      return true
    end,
  }
  _G.SlashCmdList = {}

  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  local ok, result = pcall(Bootstrap.Initialize, factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      settings = {},
      groupChats = {
        abcd1234 = { id = "abcd1234", name = "Crew", members = { "Anna-Kazzak" }, createdAt = 1 },
        efgh5678 = { id = "efgh5678", name = "Old", members = {}, createdAt = 1, left = true },
      },
    },
    characterState = { window = {}, icon = {} },
  })
  local slash = _G.SlashCmdList["WHISPERMESSENGER"]

  package.loaded["UI.Theme"] = savedTheme
  package.loaded["UI.Theme.Fonts"] = savedFonts
  package.loaded["Core.Bootstrap.WindowRuntime"] = savedWindowRuntime
  _G.UIParent = savedUIParent

  if not ok then
    _G.C_ChatInfo = savedChatInfo
    _G.SlashCmdList = savedSlashCmdList
    error(result, 0)
  end
  local runtime = result
  assert(registered["WMGC"] == true, "boot registers the group chat prefix")
  assert(type(runtime.groupChats) == "table", "the service is on the runtime")
  local row = runtime.store.conversations["wmgroup::abcd1234"]
  assert(row and row.channel == "WM_GROUP" and row.title == "Crew", "a joined group keeps its row")
  assert(runtime.store.conversations["wmgroup::efgh5678"] == nil, "a left group gets no new row")

  slash("group Bela")
  assert(#selected == 1 and string.find(selected[1], "wmgroup::", 1, true) == 1, "/wmsg group opens the new chat")

  _G.C_ChatInfo = savedChatInfo
  _G.SlashCmdList = savedSlashCmdList
end
