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
end
