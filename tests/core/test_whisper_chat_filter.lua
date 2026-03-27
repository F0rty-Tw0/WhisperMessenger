local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedFilter = _G.ChatFrame_AddMessageEventFilter

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil

  -- -----------------------------------------------------------------------
  -- test_registers_whisper_chat_filters
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    assert(
      type(filters["CHAT_MSG_WHISPER"]) == "function",
      "test_registers_whisper_chat_filters: should register filter for CHAT_MSG_WHISPER"
    )
    assert(
      type(filters["CHAT_MSG_BN_WHISPER"]) == "function",
      "test_registers_whisper_chat_filters: should register filter for CHAT_MSG_BN_WHISPER"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_filter_passes_through_by_default
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    local suppress = filters["CHAT_MSG_WHISPER"](nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(suppress == false, "test_filter_passes_through_by_default: filter should return false by default")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_suppresses_when_hideFromDefaultChat_is_true
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = { hideFromDefaultChat = true },
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    local suppress = filters["CHAT_MSG_WHISPER"](nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(suppress == true, "test_filter_suppresses: filter should return true when hideFromDefaultChat is true")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_preserves_reply_target_for_whisper
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    local lastTellTarget = nil
    local lastTellType = nil
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end
    _G.ChatEdit_SetLastTellTarget = function(name, chatType)
      lastTellTarget = name
      lastTellType = chatType
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = { hideFromDefaultChat = true },
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    filters["CHAT_MSG_WHISPER"](nil, "CHAT_MSG_WHISPER", "hello", "Arthas-Area52")
    assert(lastTellTarget == "Arthas-Area52", "test_filter_preserves_reply_target: should set target to sender")
    assert(lastTellType == "WHISPER", "test_filter_preserves_reply_target: should set type to WHISPER")

    filters["CHAT_MSG_BN_WHISPER"](nil, "CHAT_MSG_BN_WHISPER", "hi there", "Jaina")
    assert(lastTellTarget == "Jaina", "test_filter_preserves_reply_target: should set BN target")
    assert(lastTellType == "BN_WHISPER", "test_filter_preserves_reply_target: should set type to BN_WHISPER")

    _G.ChatEdit_SetLastTellTarget = nil
  end

  -- -----------------------------------------------------------------------
  -- test_filter_passes_through_when_hideFromDefaultChat_is_false
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = { hideFromDefaultChat = false },
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    local suppress = filters["CHAT_MSG_WHISPER"](nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(
      suppress == false,
      "test_filter_passes_through: filter should return false when hideFromDefaultChat is disabled"
    )

    local bnSuppress = filters["CHAT_MSG_BN_WHISPER"](nil, "CHAT_MSG_BN_WHISPER", "hi", "Jaina")
    assert(
      bnSuppress == false,
      "test_filter_passes_through: BN filter should return false when hideFromDefaultChat is disabled"
    )
  end

  _G.ChatFrame_AddMessageEventFilter = savedFilter
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
