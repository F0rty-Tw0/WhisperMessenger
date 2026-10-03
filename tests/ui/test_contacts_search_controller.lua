local ContactsSearchController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsSearchController")

local function installFakeTimer()
  local timers = {}
  rawset(_G, "C_Timer", {
    NewTimer = function(seconds, callback)
      local timer = { seconds = seconds, callback = callback, cancelled = false }
      function timer:Cancel()
        self.cancelled = true
      end
      timers[#timers + 1] = timer
      return timer
    end,
  })

  local function fire(timer)
    if not timer.cancelled then
      timer.callback(timer)
    end
  end

  return {
    timers = timers,
    fireAll = function()
      for _, timer in ipairs(timers) do
        fire(timer)
      end
    end,
    fireRaw = function(timer)
      timer.callback(timer)
    end,
  }
end

local function makeInput()
  local input = { text = "", scripts = {} }
  function input:SetScript(name, handler)
    self.scripts[name] = handler
  end
  function input:GetText()
    return self.text
  end
  function input:SetText(value)
    self.text = value
  end
  function input:ClearFocus() end
  return input
end

local function buildHarness()
  local input = makeInput()
  local filterCalls = {}
  local pagingResets = {}
  local contactSearch = {
    NormalizeSearchQuery = function(raw)
      return string.lower(raw or "")
    end,
    BuildVisibleContacts = function(items, query)
      filterCalls[#filterCalls + 1] = query
      return items
    end,
    IsConversationVisible = function()
      return true
    end,
  }
  local controller = ContactsSearchController.Create({
    contacts = {},
    contactsController = {
      refresh = function(_rows, _selectedKey, resetPaging)
        pagingResets[#pagingResets + 1] = resetPaging == true
        return {}
      end,
    },
    contactSearch = contactSearch,
    contactsSearchInput = input,
    initialContacts = {},
  })
  controller.bindInputScripts()

  local function typeText(text)
    input.text = text
    input.scripts.OnTextChanged(input, true)
  end

  return {
    input = input,
    filterCalls = filterCalls,
    pagingResets = pagingResets,
    controller = controller,
    typeText = typeText,
  }
end

local function withFakeTimer(fn)
  local previousTimer = _G.C_Timer
  local fake = installFakeTimer()
  local ok, err = pcall(fn, fake)
  rawset(_G, "C_Timer", previousTimer)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_fast_typing_runs_one_filter_pass
  withFakeTimer(function(fake)
    local h = buildHarness()
    h.typeText("a")
    h.typeText("ar")
    h.typeText("art")
    assert(#h.filterCalls == 0, "typing must not filter before the debounce fires; got " .. #h.filterCalls)
    fake.fireAll()
    assert(#h.filterCalls == 1, "three quick keystrokes must run one filter pass; got " .. #h.filterCalls)
    assert(h.filterCalls[1] == "art", "debounced pass must use the latest query; got " .. tostring(h.filterCalls[1]))
  end)

  -- test_clearing_text_applies_immediately
  withFakeTimer(function()
    local h = buildHarness()
    h.typeText("art")
    h.typeText("")
    assert(#h.filterCalls == 1, "emptying the search box must filter immediately; got " .. #h.filterCalls)
    assert(h.filterCalls[1] == "", "immediate pass must use the empty query")
  end)

  -- test_escape_applies_immediately
  withFakeTimer(function()
    local h = buildHarness()
    h.typeText("art")
    h.input.scripts.OnEscapePressed(h.input)
    assert(#h.filterCalls == 1, "Escape must filter immediately; got " .. #h.filterCalls)
    assert(h.filterCalls[1] == "", "Escape pass must use the empty query")
  end)

  -- test_stale_timer_after_clear_is_noop
  withFakeTimer(function(fake)
    local h = buildHarness()
    h.typeText("art")
    h.typeText("")
    fake.fireRaw(fake.timers[1])
    assert(#h.filterCalls == 1, "timer scheduled before clear must not filter again; got " .. #h.filterCalls)
  end)

  -- test_refresh_during_debounce_still_resets_paging
  withFakeTimer(function()
    local h = buildHarness()
    h.typeText("art")
    h.controller.refresh({}, nil)
    assert(#h.pagingResets == 1, "external refresh must apply the pending query; got " .. #h.pagingResets)
    assert(h.pagingResets[1] == true, "a new query must start the list from the top even when another refresh applies it")
  end)

  -- test_without_new_timer_filters_immediately
  do
    local previousTimer = _G.C_Timer
    rawset(_G, "C_Timer", nil)
    local ok, err = pcall(function()
      local h = buildHarness()
      h.typeText("art")
      assert(#h.filterCalls == 1, "missing C_Timer must fall back to immediate filtering; got " .. #h.filterCalls)
    end)
    rawset(_G, "C_Timer", previousTimer)
    if not ok then
      error(err, 0)
    end
  end
end
