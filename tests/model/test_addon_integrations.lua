local AddonIntegrations = require("WhisperMessenger.Model.AddonIntegrations")

local function titles(map)
  return function(name)
    return map[name]
  end
end

return function()
  -- test_new_name_is_saved_allowed_and_seen
  do
    local account = {}
    local reg = AddonIntegrations.New(account, titles({ CraftAlert = "Craft Alert" }))
    reg.touch("CraftAlert")
    assert(reg.isAllowed("CraftAlert") == true)
    assert(account.addonIntegrations.CraftAlert.allowed == true)
    assert(account.addonIntegrations.CraftAlert.title == "Craft Alert")
    assert(reg.rows()[1].seen == true and reg.rows()[1].name == "CraftAlert")
  end

  -- test_unknown_name_counts_as_allowed
  do
    assert(AddonIntegrations.New({}, titles({})).isAllowed("Nope") == true)
  end

  -- test_saved_tick_survives_a_new_session_and_marks_connect
  do
    local account = { addonIntegrations = { Foo = { title = "Foo", allowed = false } } }
    local reg = AddonIntegrations.New(account, titles({}))
    assert(reg.rows()[1].seen == false, "loaded from save, not seen yet")
    reg.touch("Foo")
    assert(reg.isAllowed("Foo") == false and reg.connectedRefused("Foo") == true)
    reg.setAllowed("Foo", true)
    assert(reg.connectedRefused("Foo") == true, "mark never changes after the first touch")
    reg.touch("Foo")
    assert(reg.isAllowed("Foo") == true and reg.connectedRefused("Foo") == true, "a later touch must not overwrite the mark")
  end

  -- test_corrupt_saved_rows_are_dropped_or_repaired_and_never_raise
  do
    local account = {
      addonIntegrations = {
        [""] = 5,
        CraftAlert = true,
        [7] = { allowed = true },
        Good = { title = "Good", allowed = false },
        Odd = { title = 12, allowed = "yes" },
      },
    }
    local reg = AddonIntegrations.New(account, titles({}))
    local ok, err = pcall(function()
      reg.touch("")
      reg.touch("CraftAlert")
      assert(reg.isAllowed("") == true and reg.isAllowed("CraftAlert") == true)
      reg.setAllowed("CraftAlert", false)
      assert(reg.isAllowed("CraftAlert") == false)
    end)
    assert(ok, err)
    local names = {}
    for _, row in ipairs(reg.rows()) do
      assert(type(row.name) == "string" and type(row.title) == "string" and type(row.allowed) == "boolean")
      names[#names + 1] = row.name
    end
    assert(table.concat(names, ",") == "CraftAlert,Good,Odd,", table.concat(names, ","))
    assert(account.addonIntegrations[7] == nil)
    assert(reg.isAllowed("Good") == false, "a valid saved tick is kept")
    assert(account.addonIntegrations.Odd.allowed == true and account.addonIntegrations.Odd.title == nil)
  end

  -- test_state_by_event_table (spec State x event, one row per assertion)
  do
    local account = {
      addonIntegrations = {
        ["A-"] = { title = "A-", allowed = true },
        ["R-"] = { title = "R-", allowed = false },
      },
    }
    local reg = AddonIntegrations.New(account, titles({}))
    local events = {}
    reg.onChange(function(event, name)
      events[#events + 1] = event .. ":" .. name
    end)
    reg.touch("New") -- New -> A
    reg.touch("New") -- A -> A, no second event
    reg.setAllowed("New", false) -- A -> R
    reg.setAllowed("New", false) -- R untick ignored
    reg.setAllowed("New", true) -- R -> A
    reg.setAllowed("A-", false) -- A- -> R-
    reg.setAllowed("R-", true) -- R- -> A-
    assert(table.concat(events, ",") == "touched:New,refused:New,allowed:New,refused:A-,allowed:R-", table.concat(events, ","))
    assert(reg.forget("New") == false, "a seen row has no Forget")
    assert(reg.forget("A-") == true and account.addonIntegrations["A-"] == nil)
    assert(events[#events] == "forgotten:A-")
    assert(reg.forget("A-") == false, "already gone")
    reg.touch("R-") -- R- -> connect again, saved tick (now true) -> A
    assert(reg.connectedRefused("R-") == false)
  end

  -- test_connect_after_forget_is_new_again
  do
    local reg = AddonIntegrations.New({ addonIntegrations = { X = { title = "X", allowed = false } } }, titles({}))
    reg.forget("X")
    reg.touch("X")
    assert(reg.isAllowed("X") == true, "forgotten choice is gone, D6 default")
  end

  -- test_rows_order_seen_first_then_not_loaded_colour_codes_ignored_shared_last
  do
    local account = {
      addonIntegrations = {
        Zed = { title = "Zed", allowed = true },
        Bravo = { title = "bravo", allowed = true },
      },
    }
    local reg = AddonIntegrations.New(account, titles({ CraftAlert = "|cff00ff00Craft|r Alert", Delta = "Delta" }))
    reg.touch("")
    reg.touch("CraftAlert")
    reg.touch("Delta")
    local names = {}
    for _, row in ipairs(reg.rows()) do
      names[#names + 1] = row.name
    end
    -- unstripped "|cff..." would sort after "delta"; unlowered "Zed" would sort before "bravo"
    assert(table.concat(names, ",") == "CraftAlert,Delta,Bravo,Zed,", table.concat(names, ","))
    assert(reg.rows()[5].shared == true and reg.rows()[1].shared == false)
  end

  -- test_shared_row_hidden_until_used_or_saved_unticked
  do
    local reg = AddonIntegrations.New({}, titles({}))
    assert(#reg.rows() == 0)
    local reg2 = AddonIntegrations.New({ addonIntegrations = { [""] = { title = "", allowed = false } } }, titles({}))
    assert(#reg2.rows() == 1 and reg2.rows()[1].seen == false, "saved unticked shows as not loaded")
    assert(reg2.forget("") == true, "an unused Other addons row may be forgotten")
  end

  -- test_shared_touch_never_looks_up_a_title
  do
    local looked = false
    local reg = AddonIntegrations.New({}, function()
      looked = true
    end)
    reg.touch("")
    assert(looked == false)
  end

  -- test_title_refreshes_on_touch_and_falls_back_to_name
  do
    local account = { addonIntegrations = { Foo = { title = "Old", allowed = true } } }
    local reg = AddonIntegrations.New(account, titles({ Foo = "New" }))
    reg.touch("Foo")
    assert(account.addonIntegrations.Foo.title == "New")
    local reg2 = AddonIntegrations.New({}, function()
      error("boom")
    end)
    reg2.touch("Bar")
    assert(reg2.rows()[1].title == "Bar", "lookup raised: show the given name")
  end

  -- test_ownership_claims
  do
    local reg = AddonIntegrations.New({}, titles({}))
    reg.claim("panel", "ca", "CraftAlert")
    reg.claim("panel", "x", nil)
    reg.claim("note", "ca", "")
    assert(reg.ownerOf("panel", "ca") == "CraftAlert" and reg.ownerOf("note", "ca") == "")
    assert(reg.ownerOf("panel", "x") == nil, "no caller owns nothing")
    assert(#reg.ownedBy("panel", "CraftAlert") == 1 and reg.ownedBy("panel", "CraftAlert")[1] == "ca")
    reg.claim("panel", "ca", "Other")
    assert(#reg.ownedBy("panel", "CraftAlert") == 0, "ownership moves with the latest claim")
  end

  -- test_nil_account_state_keeps_rows_in_memory
  do
    local reg = AddonIntegrations.New(nil, titles({}))
    reg.touch("Foo")
    assert(reg.isAllowed("Foo") == true and #reg.rows() == 1)
  end
end
