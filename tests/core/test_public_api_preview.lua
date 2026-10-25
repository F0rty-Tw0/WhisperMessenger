local ExternalPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local PublicApi = require("WhisperMessenger.Core.PublicApi")

local NOW = 500

-- opts: noWidget (getWidgetIcon returns nil), iconHidden, settings, panelShown
-- (the visible panel's key; "ca" is the one registered panel). The returned
-- state's panelShown can be flipped by a row.
local function makeRuntime(opts)
  opts = opts or {}
  local holder = ExternalPreview.New({
    now = function()
      return NOW
    end,
  })
  local state = { holder = holder, updates = 0, panelShown = opts.panelShown }
  local icon = {
    isExternalPreviewShown = function()
      return not opts.iconHidden and holder.get() ~= nil
    end,
  }
  local runtime = {
    externalPreview = holder,
    accountState = { settings = opts.settings or {} },
    getWidgetIcon = function()
      if opts.noWidget then
        return nil
      end
      return icon
    end,
    updateIconSurfaces = function()
      state.updates = state.updates + 1
    end,
  }
  if opts.panelShown ~= nil then
    runtime.panelRegistry = {
      get = function(key)
        return key == "ca" and {} or nil
      end,
    }
    runtime.isWindowVisible = function()
      return true
    end
    runtime.window = {
      getVisiblePanel = function()
        return state.panelShown
      end,
    }
  end
  state.api = PublicApi.Build(runtime)
  return state
end

local function preview(fields)
  local p = { sender = "S", text = "T" }
  for k, v in pairs(fields or {}) do
    p[k] = v
  end
  return p
end

return function()
  local function test_show_stores_stamps_and_updates_surfaces()
    local s = makeRuntime()
    assert(s.api.ShowPreview("ca", preview()) == true, "ShowPreview accepts a valid preview")
    assert(s.holder.get().stamp == NOW and s.holder.keyOf() == "ca", "the entry is stored with the current time")
    assert(s.updates == 1, "icon surfaces refresh once, got " .. s.updates)
  end

  local function test_bad_arguments_return_false()
    local badKeys = { nil, {}, "", "   " }
    for i = 1, 4 do
      local s = makeRuntime()
      assert(s.api.ShowPreview(badKeys[i], preview()) == false, "bad key " .. i .. " is refused")
      assert(s.holder.get() == nil and s.updates == 0, "bad key " .. i .. " stores nothing")
    end
    local badPreviews = {
      "nil",
      {},
      preview({ sender = "" }),
      preview({ text = "" }),
      preview({ sender = 5 }),
      preview({ classTag = 5 }),
      preview({ onClick = "x" }),
      preview({ onDismiss = 5 }),
      preview({ onShown = {} }),
    }
    for i, p in ipairs(badPreviews) do
      local s = makeRuntime()
      local arg = p ~= "nil" and p or nil
      assert(s.api.ShowPreview("ca", arg) == false, "bad preview " .. i .. " is refused")
      assert(s.holder.get() == nil and s.updates == 0, "bad preview " .. i .. " stores nothing")
    end
  end

  local function test_false_when_widget_not_in_use()
    local s = makeRuntime({ noWidget = true })
    assert(s.api.ShowPreview("ca", preview()) == false, "no widget icon refuses the preview")
    assert(s.holder.get() == nil, "nothing stored without a widget")
  end

  local function test_false_when_previews_are_turned_off()
    local s = makeRuntime({ settings = { showWidgetMessagePreview = false } })
    assert(s.api.ShowPreview("ca", preview()) == false, "previews turned off refuse the preview")
    assert(s.holder.get() == nil, "nothing stored while previews are off")
  end

  local function test_is_shown_needs_key_and_visible_frame()
    local s = makeRuntime()
    s.api.ShowPreview("ca", preview())
    assert(s.api.IsPreviewShown("ca") == true, "own key and shown frame")
    assert(s.api.IsPreviewShown("other") == false, "another key is not shown")
    assert(s.api.IsPreviewShown(nil) == false, "a bad key is not shown")
    local hidden = makeRuntime({ iconHidden = true })
    hidden.api.ShowPreview("ca", preview())
    assert(hidden.api.IsPreviewShown("ca") == false, "a hidden frame is not shown")
  end

  local function test_hide_only_hides_own_source()
    local s = makeRuntime()
    s.api.ShowPreview("ca", preview())
    assert(s.api.HidePreview("other") == false and s.holder.get() ~= nil, "another source cannot hide it")
    assert(s.updates == 1, "a refused hide does not refresh")
    assert(s.api.HidePreview("ca") == true and s.holder.get() == nil, "the owner hides it")
    assert(s.updates == 2, "hiding refreshes the icon surfaces")
    assert(s.api.IsPreviewShown("ca") == false, "hidden preview is not shown")
  end

  local function test_second_source_replaces_the_first_silently()
    local s = makeRuntime()
    local dismissed = 0
    s.api.ShowPreview(
      "a",
      preview({
        onDismiss = function()
          dismissed = dismissed + 1
        end,
      })
    )
    assert(s.api.ShowPreview("b", preview()) == true, "a second source is accepted")
    assert(s.holder.keyOf() == "b" and dismissed == 0, "the first is replaced without its onDismiss")
  end

  local function test_non_boolean_pulse_is_refused()
    local s = makeRuntime()
    assert(
      s.api.ShowPreview("ca", preview({ pulse = "yes" })) == false and s.api.ShowPreview("ca", preview({ pulse = 1 })) == false,
      "a non-boolean pulse is refused"
    )
    assert(s.holder.get() == nil and s.updates == 0, "a refused pulse stores nothing")
  end

  local function test_pulse_true_arms_the_entry()
    local s = makeRuntime()
    s.api.ShowPreview("ca", preview({ pulse = true }))
    assert(s.holder.get().pulse == true, "pulse = true arms the entry")
  end

  local function test_no_pulse_means_no_glow()
    local s = makeRuntime()
    s.api.ShowPreview("ca", preview())
    assert(s.holder.get().pulse == false, "no pulse field stores false")
  end

  local function test_pulse_is_not_armed_while_the_owners_panel_shows()
    local s = makeRuntime({ panelShown = "ca" })
    s.api.ShowPreview("ca", preview({ pulse = true }))
    assert(s.holder.get().pulse == false, "owner is looking at its panel")
  end

  local function test_another_panel_showing_does_not_block_the_pulse()
    local s = makeRuntime({ panelShown = "other" })
    s.api.ShowPreview("ca", preview({ pulse = true }))
    assert(s.holder.get().pulse == true, "only the owner's own panel disarms")
  end

  local function test_a_new_show_preview_arms_again_after_the_panel_closes()
    local s = makeRuntime({ panelShown = "ca" })
    s.api.ShowPreview("ca", preview({ pulse = true }))
    assert(s.holder.get().pulse == false, "owner is looking at its panel")
    s.panelShown = nil
    s.api.ShowPreview("ca", preview({ pulse = true }))
    assert(s.holder.get().pulse == true, "a new ShowPreview arms again")
  end

  local function test_an_overwritten_is_panel_shown_does_not_change_show_preview()
    local s = makeRuntime({ panelShown = "other" })
    s.api.IsPanelShown = function()
      return true
    end
    s.api.ShowPreview("ca", preview({ pulse = true }))
    assert(s.holder.get().pulse == true, "ShowPreview reads the panel state itself")
    s.api.IsPanelShown = nil
    assert(s.api.ShowPreview("ca", preview({ pulse = true })) == true, "and survives the key being removed")
  end

  test_an_overwritten_is_panel_shown_does_not_change_show_preview()
  test_show_stores_stamps_and_updates_surfaces()
  test_a_new_show_preview_arms_again_after_the_panel_closes()
  test_non_boolean_pulse_is_refused()
  test_pulse_true_arms_the_entry()
  test_no_pulse_means_no_glow()
  test_pulse_is_not_armed_while_the_owners_panel_shows()
  test_another_panel_showing_does_not_block_the_pulse()
  test_bad_arguments_return_false()
  test_false_when_widget_not_in_use()
  test_false_when_previews_are_turned_off()
  test_is_shown_needs_key_and_visible_frame()
  test_hide_only_hides_own_source()
  test_second_source_replaces_the_first_silently()
end
