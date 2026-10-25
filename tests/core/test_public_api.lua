local PublicApi = require("WhisperMessenger.Core.PublicApi")

local function makeRuntime(opts)
  opts = opts or {}
  local calls = {}
  local visible = opts.visible == true
  local runtime = {
    ensureWindow = function()
      calls[#calls + 1] = "ensure"
    end,
    setWindowVisible = function(v)
      visible = v
      calls[#calls + 1] = "visible:" .. tostring(v)
    end,
    isWindowVisible = function()
      return visible
    end,
    startConversation = opts.startConversation or function(name)
      calls[#calls + 1] = "start:" .. name
      return opts.startResult ~= false
    end,
    setComposerText = function(text)
      calls[#calls + 1] = "draft:" .. text
    end,
    isCompetitiveContent = function()
      return opts.competitive == true
    end,
    isMythicLockdown = function()
      return opts.mythic == true
    end,
    window = {
      composer = {
        input = {
          SetCursorPosition = function(_, n)
            calls[#calls + 1] = "cursor:" .. n
          end,
        },
      },
    },
  }
  return runtime, calls
end

local function expect(calls, want)
  assert(table.concat(calls, ",") == want, "calls: " .. table.concat(calls, ","))
end

local function withCombat(inCombat, fn)
  local saved = _G.InCombatLockdown
  rawset(_G, "InCombatLockdown", function()
    return inCombat
  end)
  local ok, err = pcall(fn)
  rawset(_G, "InCombatLockdown", saved)
  assert(ok, err)
end

return function()
  local function test_publish_sets_the_global_with_version_1()
    local saved = _G.WhisperMessengerAPI
    local api = PublicApi.Publish((makeRuntime()))
    local published = _G.WhisperMessengerAPI
    _G.WhisperMessengerAPI = saved
    assert(published == api and api.version == 1 and type(api.OpenConversation) == "function")
  end

  local function test_open_runs_ensure_show_start_in_order()
    local r, calls = makeRuntime()
    assert(PublicApi.Build(r).OpenConversation("Jaina-Proudmoore") == true)
    expect(calls, "ensure,visible:true,start:Jaina-Proudmoore")
  end

  local function test_draft_replaces_composer_text_cursor_at_end()
    local r, calls = makeRuntime()
    assert(PublicApi.Build(r).OpenConversation("Jaina", "hello") == true)
    expect(calls, "ensure,visible:true,start:Jaina,draft:hello,cursor:5")
  end

  local function test_empty_draft_is_ignored()
    local r, calls = makeRuntime()
    assert(PublicApi.Build(r).OpenConversation("Jaina", "") == true)
    expect(calls, "ensure,visible:true,start:Jaina")
  end

  local function test_bad_arguments_return_false_and_open_nothing()
    local bad = { { nil }, { 5 }, { "" }, { "   " }, { {} }, { "Jaina", 5 }, { "Jaina", {} }, { "Jaina", ("x"):rep(256) } }
    for index, args in ipairs(bad) do
      local r, calls = makeRuntime()
      assert(PublicApi.Build(r).OpenConversation(args[1], args[2]) == false, "case " .. index)
      expect(calls, "")
    end
  end

  local function test_refused_content()
    local r, calls = makeRuntime({ competitive = true, mythic = true, visible = true })
    assert(PublicApi.Build(r).OpenConversation("Jaina") == false)
    expect(calls, "")
    local r2, calls2 = makeRuntime({ mythic = true, visible = true })
    assert(PublicApi.Build(r2).OpenConversation("Jaina") == false)
    expect(calls2, "")
  end

  local function test_refused_in_combat_with_window_closed()
    withCombat(true, function()
      local r, calls = makeRuntime({ visible = false })
      assert(PublicApi.Build(r).OpenConversation("Jaina") == false)
      expect(calls, "")
    end)
  end

  local function test_combat_with_window_open_is_allowed()
    withCombat(true, function()
      local r = makeRuntime({ visible = true })
      assert(PublicApi.Build(r).OpenConversation("Jaina") == true)
    end)
  end

  local function test_failed_start_closes_what_it_opened()
    local r, calls = makeRuntime({ startResult = false })
    assert(PublicApi.Build(r).OpenConversation("Jaina") == false)
    assert(calls[#calls] == "visible:false", "last call: " .. tostring(calls[#calls]))
  end

  local function test_failed_start_keeps_an_open_window_open()
    local r, calls = makeRuntime({ startResult = false, visible = true })
    assert(PublicApi.Build(r).OpenConversation("Jaina") == false)
    expect(calls, "ensure,visible:true,start:Jaina")
  end

  local function test_internal_error_returns_false()
    local r = makeRuntime({
      startConversation = function()
        error("boom")
      end,
    })
    assert(PublicApi.Build(r).OpenConversation("Jaina") == false)
  end

  test_publish_sets_the_global_with_version_1()
  test_open_runs_ensure_show_start_in_order()
  test_draft_replaces_composer_text_cursor_at_end()
  test_empty_draft_is_ignored()
  test_bad_arguments_return_false_and_open_nothing()
  test_refused_content()
  test_refused_in_combat_with_window_closed()
  test_combat_with_window_open_is_allowed()
  test_failed_start_closes_what_it_opened()
  test_failed_start_keeps_an_open_window_open()
  test_internal_error_returns_false()
end
