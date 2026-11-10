local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- Retail and Forever: the Link button at the top of the Professions window
-- (Blizzard_ProfessionsCrafting.lua) inserts the profession link only when
-- ChatFrameUtil.GetActiveWindow() finds a Blizzard chat box, so a focused
-- composer alone never gets it from the InsertLink post-hook. A post-hook on
-- the button itself covers that gap.
return function()
  local env = LinkHooksEnv.New()
  local input = env.NewInput()
  local tradeLink = "|cffffd000|Htrade:Player-1-0001:164:164|h[Blacksmithing]|h|r"
  local savedFrame = rawget(_G, "ProfessionsFrame")
  local savedApi = rawget(_G, "C_TradeSkillUI")

  -- Mirrors Blizzard: OnClick inserts only while a Blizzard chat box is active.
  local clickHandlers = {}
  rawset(_G, "C_TradeSkillUI", {
    GetTradeSkillListLink = function()
      return tradeLink
    end,
  })
  rawset(_G, "ProfessionsFrame", {
    CraftingPage = {
      LinkButton = {
        HookScript = function(_button, _script, handler)
          table.insert(clickHandlers, handler)
        end,
      },
    },
  })
  env.LinkHooks.RegisterInput(input)

  local function clickLinkButton()
    if _G.ChatFrameUtil.GetActiveWindow() then
      _G.ChatFrameUtil.InsertLink(_G.C_TradeSkillUI.GetTradeSkillListLink())
    end
    for _, handler in ipairs(clickHandlers) do
      handler()
    end
  end

  -- test_profession_link_button_lands_in_focused_composer
  env.Reset()
  input.focused = true
  clickLinkButton()
  local landed = env.inserts[1] == tradeLink and #env.inserts == 1

  -- test_profession_link_button_skips_composer_when_blizzard_chat_box_is_open
  env.Reset()
  input.focused = true
  env.blizzardActiveWindow = {}
  clickLinkButton()
  local doubled = #env.inserts

  -- test_profession_link_button_skips_unfocused_composer
  env.Reset()
  input.focused = false
  env.blizzardActiveWindow = nil
  clickLinkButton()
  local unfocused = #env.inserts

  rawset(_G, "ProfessionsFrame", savedFrame)
  rawset(_G, "C_TradeSkillUI", savedApi)
  env.Restore()

  assert(landed, "the Link button should put the trade link in the focused composer once, got " .. tostring(env.inserts[1]))
  assert(doubled == 0, "an open Blizzard chat box must keep the link to itself, got " .. doubled)
  assert(unfocused == 0, "an unfocused composer must not receive the link, got " .. unfocused)
end
