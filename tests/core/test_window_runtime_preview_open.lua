local PreviewOpen = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewOpen")

local function build(overrides)
  overrides = overrides or {}
  local log = {}
  local window = {
    hidePanel = function()
      log[#log + 1] = "hidePanel"
    end,
    setTabMode = function(mode)
      log[#log + 1] = "tab:" .. mode
    end,
  }
  local runtime
  runtime = {
    isCompetitiveContent = function()
      return overrides.competitive == true
    end,
    isMythicLockdown = function()
      return overrides.lockdown == true
    end,
    isWindowVisible = function()
      return overrides.visible == true
    end,
    ensureWindow = function()
      log[#log + 1] = "ensureWindow"
      runtime.window = window
    end,
    setWindowVisible = function(visible)
      log[#log + 1] = "visible:" .. tostring(visible)
    end,
  }
  local contacts = {}
  local open = PreviewOpen.Create({
    runtime = runtime,
    buildContacts = function()
      return contacts
    end,
    buildLatestIncomingPreview = function(nextContacts)
      assert(nextContacts == contacts, "the preview is recomputed from the current contacts")
      return overrides.preview
    end,
    selectConversation = function(key)
      log[#log + 1] = "select:" .. key
    end,
  })
  return open, log
end

local PREVIEW = { conversationKey = "wow::jaina", senderName = "Jaina", messageText = "hi" }

return function()
  local function test_opens_the_window_on_the_previewed_whisper()
    local open, log = build({ preview = PREVIEW })
    open()
    local expected = "ensureWindow,visible:true,hidePanel,tab:whispers,select:wow::jaina"
    assert(table.concat(log, ",") == expected, "open order, got " .. table.concat(log, ","))
  end

  local function test_competitive_content_refuses_to_open()
    local open, log = build({ preview = PREVIEW, competitive = true })
    open()
    assert(#log == 0, "nothing opens in competitive content, got " .. table.concat(log, ","))
  end

  local function test_mythic_lockdown_refuses_to_open()
    local open, log = build({ preview = PREVIEW, lockdown = true })
    open()
    assert(#log == 0, "nothing opens under a mythic lockdown, got " .. table.concat(log, ","))
  end

  local function test_no_preview_at_click_time_opens_nothing()
    local open, log = build({ preview = nil })
    open()
    assert(#log == 0, "a vanished preview opens nothing, got " .. table.concat(log, ","))
  end

  local function test_open_with_a_key_selects_that_chat_not_the_latest()
    local open, log = build({ preview = { conversationKey = "wow::thrall" } })
    assert(open("wow::jaina") == true, "a keyed open reports success")
    assert(log[#log] == "select:wow::jaina", "the given key is selected, got " .. table.concat(log, ","))
  end

  local function test_refused_open_returns_false()
    local open, log = build({ preview = PREVIEW, competitive = true })
    assert(open("wow::jaina") == false, "a refused open reports failure")
    assert(#log == 0, "nothing opens when refused, got " .. table.concat(log, ","))
  end

  local function test_open_without_a_key_or_preview_returns_false()
    local open = build({ preview = nil })
    assert(open() == false, "no key and no preview reports failure")
  end

  test_opens_the_window_on_the_previewed_whisper()
  test_competitive_content_refuses_to_open()
  test_mythic_lockdown_refuses_to_open()
  test_no_preview_at_click_time_opens_nothing()
  test_open_with_a_key_selects_that_chat_not_the_latest()
  test_refused_open_returns_false()
  test_open_without_a_key_or_preview_returns_false()
end
