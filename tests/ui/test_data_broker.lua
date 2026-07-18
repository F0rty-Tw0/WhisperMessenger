local DataBroker = require("WhisperMessenger.UI.MinimapIcon.DataBroker")

local function makeFakeLdb()
  local ldb = { registered = {} }
  function ldb:NewDataObject(name, obj)
    self.registered[name] = obj
    return obj
  end
  return ldb
end

local function installLibStub(ldb)
  local original = rawget(_G, "LibStub")
  rawset(
    _G,
    "LibStub",
    setmetatable({}, {
      __call = function(_, major, _silent)
        if major == "LibDataBroker-1.1" then
          return ldb
        end
        return nil
      end,
    })
  )
  return original
end

local function makeFakeTooltip()
  local tooltip = { lines = {} }
  function tooltip:AddLine(text)
    table.insert(self.lines, text)
  end
  return tooltip
end

return function()
  -- test_format_text_defaults_to_addon_name
  do
    assert(DataBroker.FormatText(nil) == "Whisper Messenger", "nil count formats as the addon name")
    assert(DataBroker.FormatText(0) == "Whisper Messenger", "zero count formats as the addon name")
  end

  -- test_format_text_shows_unread_count
  do
    assert(DataBroker.FormatText(3) == "3 unread", "positive count formats as 'N unread'")
  end

  -- test_register_fires_on_registered_with_data_object
  do
    local ldb = makeFakeLdb()
    local originalLibStub = installLibStub(ldb)

    local registered
    DataBroker.Register({
      onRegistered = function(obj)
        registered = obj
      end,
    })

    rawset(_G, "LibStub", originalLibStub)

    assert(registered ~= nil, "onRegistered receives the data object")
    assert(registered == ldb.registered["WhisperMessenger"], "the data object is registered under the addon name")
    assert(registered.type == "launcher", "data object registers as a launcher")
    assert(type(registered.text) == "string", "data object text is a plain string (Bazooka requirement)")
  end

  -- test_click_toggles_the_messenger
  do
    local ldb = makeFakeLdb()
    local originalLibStub = installLibStub(ldb)

    local toggled = 0
    local registered
    DataBroker.Register({
      onToggle = function()
        toggled = toggled + 1
      end,
      onRegistered = function(obj)
        registered = obj
      end,
    })

    rawset(_G, "LibStub", originalLibStub)

    registered.OnClick()
    assert(toggled == 1, "clicking the launcher toggles the messenger")
  end

  -- test_tooltip_shows_cached_unread_count
  do
    local ldb = makeFakeLdb()
    local originalLibStub = installLibStub(ldb)

    local registered
    DataBroker.Register({
      onRegistered = function(obj)
        registered = obj
      end,
    })

    rawset(_G, "LibStub", originalLibStub)

    registered.unread = 4
    local tooltip = makeFakeTooltip()
    registered.OnTooltipShow(tooltip)
    assert(tooltip.lines[1] == "Whisper Messenger", "tooltip leads with the addon name")
    assert(tooltip.lines[2] == "4 unread", "tooltip shows the cached unread count")
  end

  -- test_tooltip_omits_unread_line_when_none
  do
    local ldb = makeFakeLdb()
    local originalLibStub = installLibStub(ldb)

    local registered
    DataBroker.Register({
      onRegistered = function(obj)
        registered = obj
      end,
    })

    rawset(_G, "LibStub", originalLibStub)

    local tooltip = makeFakeTooltip()
    registered.OnTooltipShow(tooltip)
    assert(#tooltip.lines == 1, "tooltip has no unread line when nothing is unread")
  end

  -- test_registration_defers_to_player_login_when_ldb_missing
  do
    local originalLibStub = rawget(_G, "LibStub")
    local originalCreateFrame = rawget(_G, "CreateFrame")
    rawset(_G, "LibStub", nil)

    local loginFrame = { events = {}, scripts = {} }
    function loginFrame:RegisterEvent(eventName)
      self.events[eventName] = true
    end
    function loginFrame:UnregisterEvent(eventName)
      self.events[eventName] = nil
    end
    function loginFrame:SetScript(eventName, handler)
      self.scripts[eventName] = handler
    end
    rawset(_G, "CreateFrame", function()
      return loginFrame
    end)

    local registered
    DataBroker.Register({
      onRegistered = function(obj)
        registered = obj
      end,
    })

    assert(registered == nil, "registration waits when LibDataBroker is absent")
    assert(loginFrame.events.PLAYER_LOGIN == true, "a PLAYER_LOGIN retry is armed")

    local ldb = makeFakeLdb()
    installLibStub(ldb)
    loginFrame.scripts.OnEvent(loginFrame)

    rawset(_G, "LibStub", originalLibStub)
    rawset(_G, "CreateFrame", originalCreateFrame)

    assert(registered ~= nil, "onRegistered fires after the deferred PLAYER_LOGIN retry")
    assert(loginFrame.events.PLAYER_LOGIN == nil, "the retry unregisters itself after firing")
  end
end
