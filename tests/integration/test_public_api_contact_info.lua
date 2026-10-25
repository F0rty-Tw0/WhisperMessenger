local PublicApiEnv = require("tests.helpers.public_api_env")

return function()
  -- test_info_set_before_the_conversation_shows_once_it_is_selected
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(api.SetContactInfo("ca", "Jaina", "Craft Alert: Belt") == true)
      assert(api.OpenConversation("Jaina") == true)
      local strip = runtime.window.conversation.infoStrip
      assert(strip.frame:IsShown() and strip.rows[1].text == "Craft Alert: Belt", "the strip shows the stored line")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  -- test_removing_it_hides_the_strip
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(api.SetContactInfo("ca", "Jaina", "Craft Alert: Belt") == true)
      assert(api.OpenConversation("Jaina") == true)
      local strip = runtime.window.conversation.infoStrip
      assert(api.SetContactInfo("ca", "Jaina", nil) == true)
      assert(not strip.frame:IsShown(), "the strip hides once the line is removed")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  -- test_other_conversation_does_not_show_it
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(api.SetContactInfo("ca", "Jaina", "Craft Alert: Belt") == true)
      assert(api.OpenConversation("Arthas") == true)
      assert(not runtime.window.conversation.infoStrip.frame:IsShown(), "Arthas has no line")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  -- test_two_spellings_of_one_chat_show_one_line_and_nil_removes_it
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(api.OpenConversation("Jaina-Proudmoore") == true)
      local strip = runtime.window.conversation.infoStrip
      assert(api.SetContactInfo("ca", "Jaina", "short") == true)
      assert(api.SetContactInfo("ca", "Jaina-Proudmoore", "full") == true)
      assert(strip.height() == 22 and strip.rows[1].text == "full", "one 22 px line, the latest text")
      assert(api.SetContactInfo("ca", "Jaina", nil) == true)
      assert(not strip.frame:IsShown(), "nil removes the source's note whichever spelling it used")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end

  -- test_blank_text_shows_no_bar
  do
    local runtime, api = PublicApiEnv.Initialize({})
    local ok, err = pcall(function()
      assert(api.OpenConversation("Jaina") == true)
      local strip = runtime.window.conversation.infoStrip
      assert(api.SetContactInfo("ca", "Jaina", "x") == true)
      assert(api.SetContactInfo("ca", "Jaina", "  ") == true, "blank counts as a removal")
      assert(not strip.frame:IsShown() and strip.height() == 0, "no empty bar")
    end)
    PublicApiEnv.Reset()
    assert(ok, err)
  end
end
