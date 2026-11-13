local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")

local clock = 0

local function newHolder()
  return ExternalPreview.New({
    now = function()
      return clock
    end,
  })
end

return function()
  local function test_set_stamps_the_entry_and_fills_the_slot()
    clock = 100
    local h = newHolder()
    local e = h.set("ca", { sender = "S", text = "T" })
    assert(e.stamp == 100 and h.get() == e and h.keyOf() == "ca", "set stamps and stores the entry")
    assert(e.sourceKey == "ca" and e.sender == "S" and e.text == "T", "entry carries the preview fields")
  end

  local function test_set_carries_the_detail_line()
    local h = newHolder()
    assert(h.set("ca", { sender = "S", text = "T", detail = "D" }).detail == "D", "entry carries the detail")
  end

  local function test_pulse_is_stored_only_as_true_and_only_when_the_owner_is_not_looking()
    local h = newHolder()
    assert(h.set("ca", { sender = "S", text = "T", pulse = true }, false).pulse == true, "armed")
    assert(h.set("ca", { sender = "S", text = "T", pulse = true }, true).pulse == false, "owner's panel shows")
    assert(h.set("ca", { sender = "S", text = "T" }, false).pulse == false, "no pulse field")
  end

  local function test_click_clears_the_slot_then_runs_the_callback()
    local h = newHolder()
    local ran = {}
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      onClick = function()
        ran[#ran + 1] = h.get() == nil and "click-after-clear" or "click-before-clear"
      end,
    })
    e.onClick()
    assert(ran[1] == "click-after-clear", "click clears the slot, then runs the caller's callback")
    assert(h.get() == nil, "slot stays empty")
  end

  local function test_dismiss_clears_the_slot_then_runs_the_callback()
    local h = newHolder()
    local ran = 0
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      onDismiss = function()
        ran = ran + 1
      end,
    })
    e.onDismiss()
    assert(ran == 1 and h.get() == nil, "dismiss clears the slot and runs the caller's callback")
  end

  local function test_on_shown_keeps_the_entry()
    local h = newHolder()
    local shown = 0
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      onShown = function()
        shown = shown + 1
      end,
    })
    e.onShown()
    assert(shown == 1 and h.get() == e, "onShown runs the callback and keeps the entry")
  end

  local function test_missing_callbacks_still_get_wrappers()
    local h = newHolder()
    local e = h.set("ca", { sender = "S", text = "T" })
    assert(type(e.onClick) == "function" and type(e.onDismiss) == "function" and type(e.onShown) == "function", "every wrapper exists")
    e.onShown()
    e.onClick()
    assert(h.get() == nil, "a click without a callback still clears the slot")
  end

  local function test_clear_needs_the_current_key()
    local h = newHolder()
    local e = h.set("ca", { sender = "S", text = "T" })
    assert(h.clear("other") == false and h.get() == e, "another key keeps the entry")
    assert(h.clear("ca") == true and h.get() == nil, "the current key clears it")
    assert(h.clear("ca") == false, "nothing left to clear")
  end

  local function test_clear_without_key_drops_any_entry()
    local h = newHolder()
    h.set("ca", { sender = "S", text = "T" })
    assert(h.clear() == true and h.get() == nil and h.keyOf() == nil, "no key clears whatever is there")
  end

  local function test_throwing_callback_does_not_propagate()
    local h = newHolder()
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      onClick = function()
        error("boom")
      end,
    })
    local ok = pcall(e.onClick)
    assert(ok, "a caller error stays inside the wrapper")
  end

  local function test_stale_entry_does_not_clear_the_new_one()
    local h = newHolder()
    local old = h.set("a", { sender = "S", text = "T" })
    local new = h.set("b", { sender = "S2", text = "T2" })
    old.onClick()
    old.onDismiss()
    assert(h.get() == new, "an old entry's callbacks leave the new one alone")
  end

  -- A holder whose askWho logs into order.
  local function newAskingHolder(order)
    return ExternalPreview.New({
      now = function()
        return clock
      end,
      askWho = function(name)
        order[#order + 1] = "who:" .. name
      end,
    })
  end

  -- In game SendWho is blocked once the caller's click code has run (a sent
  -- whisper, an opened window): the /who must be the click's first act.
  local function test_click_asks_who_before_the_callback()
    local order = {}
    local h = newAskingHolder(order)
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      who = "Jaina-Proudmoore",
      onClick = function()
        order[#order + 1] = "click"
      end,
    })
    e.onClick()
    assert(table.concat(order, ",") == "who:Jaina-Proudmoore,click", table.concat(order, ","))
  end

  local function test_click_without_who_asks_nothing()
    local order = {}
    local h = newAskingHolder(order)
    h.set("ca", { sender = "S", text = "T" }).onClick()
    h.set("ca", { sender = "S", text = "T", who = "" }).onClick()
    assert(#order == 0, "no name, no /who: " .. table.concat(order, ","))
  end

  local function test_dismiss_and_shown_ask_nothing()
    local order = {}
    local h = newAskingHolder(order)
    local e = h.set("ca", { sender = "S", text = "T", who = "Jaina" })
    e.onShown()
    e.onDismiss()
    assert(#order == 0, "only a click asks: " .. table.concat(order, ","))
  end

  local function test_throwing_ask_still_runs_the_callback()
    local ran = false
    local h = ExternalPreview.New({
      now = function()
        return clock
      end,
      askWho = function()
        error("boom")
      end,
    })
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      who = "Jaina",
      onClick = function()
        ran = true
      end,
    })
    assert(pcall(e.onClick) and ran, "a failed /who never costs the caller its click")
  end

  -- A whisper the caller's onClick starts must not ask /who: by then the
  -- game blocks SendWho. The flag tells our SendTell hooks to skip it.
  local function test_running_click_is_set_only_during_the_callback()
    local seen = {}
    local h = newAskingHolder(seen)
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      who = "Jaina",
      onClick = function()
        seen[#seen + 1] = "click:" .. tostring(h.isRunningClick())
      end,
    })
    assert(h.isRunningClick() == false, "idle before the click")
    e.onClick()
    assert(table.concat(seen, ",") == "who:Jaina,click:true", table.concat(seen, ","))
    assert(h.isRunningClick() == false, "reset after the click")
  end

  local function test_running_click_resets_after_a_throwing_callback()
    local h = newHolder()
    local e = h.set("ca", {
      sender = "S",
      text = "T",
      onClick = function()
        error("boom")
      end,
    })
    e.onClick()
    assert(h.isRunningClick() == false, "a caller error still resets the flag")
  end

  test_set_stamps_the_entry_and_fills_the_slot()
  test_running_click_is_set_only_during_the_callback()
  test_running_click_resets_after_a_throwing_callback()
  test_click_asks_who_before_the_callback()
  test_click_without_who_asks_nothing()
  test_dismiss_and_shown_ask_nothing()
  test_throwing_ask_still_runs_the_callback()
  test_set_carries_the_detail_line()
  test_pulse_is_stored_only_as_true_and_only_when_the_owner_is_not_looking()
  test_click_clears_the_slot_then_runs_the_callback()
  test_dismiss_clears_the_slot_then_runs_the_callback()
  test_on_shown_keeps_the_entry()
  test_missing_callbacks_still_get_wrappers()
  test_clear_needs_the_current_key()
  test_clear_without_key_drops_any_entry()
  test_throwing_callback_does_not_propagate()
  test_stale_entry_does_not_clear_the_new_one()
end
