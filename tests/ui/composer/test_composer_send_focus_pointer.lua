local Env = require("tests.helpers.composer_send_focus_env")

local newEnv = Env.NewEnv

local FOCUS_GLOBALS = { "GetMouseFoci", "GetMouseFocus", "WhisperMessengerToggleIcon" }

-- Runs fn with the cursor over `focus`, through Retail's GetMouseFoci list or
-- the Classic flavors' GetMouseFocus, and restores the globals after.
local function withFocus(shape, focus, fn)
  local saved = {}
  for _, name in ipairs(FOCUS_GLOBALS) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, nil)
  end
  if shape == "foci" then
    rawset(_G, "GetMouseFoci", function()
      return { focus }
    end)
  else
    rawset(_G, "GetMouseFocus", function()
      return focus
    end)
  end
  local ok, err = pcall(fn)
  for _, name in ipairs(FOCUS_GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

-- Enter in combat with the cursor off the window's own rect.
local function clickInCombat(env)
  env.startCombat()
  env.window.mouseOver = false
  env.pressKey()
end

return function()
  local savedUIParent = _G.UIParent

  for _, shape in ipairs({ "foci", "focus" }) do
    -- test_combat_click_over_tab_below_window_focuses
    do
      local env = newEnv()
      local tabStrip = env.factory.CreateFrame("Frame", nil, env.window)
      local tab = env.factory.CreateFrame("Button", nil, tabStrip)
      withFocus(shape, tab, function()
        clickInCombat(env)
      end)
      assert(env.input._hasFocus == true, shape .. ": the tabs hang below the window and count as over it")
    end

    -- test_combat_click_over_unrelated_frame_does_nothing
    do
      local env = newEnv()
      local other = env.factory.CreateFrame("Button", nil, _G.UIParent)
      withFocus(shape, other, function()
        clickInCombat(env)
      end)
      assert(env.input._hasFocus ~= true, shape .. ": another addon's frame is not the window")
    end

    -- test_combat_click_over_docked_toggle_icon_focuses
    do
      local env = newEnv()
      local icon = env.factory.CreateFrame("Button", nil, _G.UIParent)
      local portrait = env.factory.CreateFrame("Frame", nil, env.window)
      icon:SetPoint("CENTER", portrait:CreateTexture(nil, "OVERLAY"), "CENTER", 0, 0)
      withFocus(shape, icon, function()
        rawset(_G, "WhisperMessengerToggleIcon", icon)
        clickInCombat(env)
      end)
      assert(env.input._hasFocus == true, shape .. ": the icon docked in the window's corner counts as over it")
    end

    -- test_combat_click_over_floating_toggle_icon_does_nothing
    do
      local env = newEnv()
      local icon = env.factory.CreateFrame("Button", nil, _G.UIParent)
      icon:SetPoint("CENTER", _G.UIParent, "BOTTOMLEFT", 100, 100)
      withFocus(shape, icon, function()
        rawset(_G, "WhisperMessengerToggleIcon", icon)
        clickInCombat(env)
      end)
      assert(env.input._hasFocus ~= true, shape .. ": the icon floating away from the window is not over it")
    end

    -- test_combat_click_over_portrait_past_window_edge_focuses
    do
      local env = newEnv()
      env.window.PortraitContainer = env.factory.CreateFrame("Frame", nil, env.window)
      env.window.PortraitContainer.mouseOver = true
      local world = env.factory.CreateFrame("Frame", nil, nil)
      withFocus(shape, world, function()
        clickInCombat(env)
      end)
      assert(env.input._hasFocus == true, shape .. ": the portrait sticks out past the window's corner and counts as over it")
    end
  end

  -- test_combat_click_with_empty_foci_does_nothing_off_window
  do
    local env = newEnv()
    withFocus("foci", nil, function()
      clickInCombat(env)
    end)
    assert(env.input._hasFocus ~= true, "nothing under the mouse: only the window's own rect counts")
  end

  -- test_combat_click_with_no_focus_api_does_nothing_off_window
  do
    local env = newEnv()
    withFocus("focus", nil, function()
      rawset(_G, "GetMouseFocus", nil)
      clickInCombat(env)
    end)
    assert(env.input._hasFocus ~= true, "no frame-under-mouse API: only the window's own rect counts")
  end

  _G.UIParent = savedUIParent
end
