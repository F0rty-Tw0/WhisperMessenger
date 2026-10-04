local MessageSplit = require("WhisperMessenger.Util.MessageSplit")

local function texts(parts)
  local result = {}
  for index, part in ipairs(parts) do
    result[index] = part.text
  end
  return table.concat(result, "\n")
end

local function assertParts(parts, expected, message)
  assert(#parts == #expected, message .. ": expected " .. #expected .. " parts, got " .. #parts .. "\n" .. texts(parts))
  for index, want in ipairs(expected) do
    assert(parts[index].text == want, message .. ": part " .. index .. " is [" .. tostring(parts[index].text) .. "]")
  end
end

return function()
  -- test_text_that_fits_is_one_part_unchanged
  local short = MessageSplit.Split("  hi there  ", 255)
  assertParts(short, { "  hi there  " }, "fits")
  assert(short[1].join == nil, "the only part has no join")

  -- test_breaks_at_the_last_space_that_fits
  assertParts(MessageSplit.Split("aaaa bbbb cccc", 9), { "aaaa bbbb", "cccc" }, "word break")

  -- test_drops_the_whole_whitespace_run_at_a_break
  local trimmed = MessageSplit.Split("aaaa  \t  bbbb", 6)
  assertParts(trimmed, { "aaaa", "bbbb" }, "whitespace run")
  assert(trimmed[2].join == " ", "the dropped run becomes one space")

  -- test_join_attaches_to_the_following_part
  local joined = MessageSplit.Split("aaaa bbbb", 4)
  assertParts(joined, { "aaaa", "bbbb" }, "join")
  assert(joined[1].join == nil and joined[2].join == " ", "the separator travels with part 2")

  -- test_long_word_is_hard_cut_with_an_empty_join
  local long = MessageSplit.Split(string.rep("a", 300), 255)
  assertParts(long, { string.rep("a", 255), string.rep("a", 45) }, "hard cut")
  assert(long[2].join == "", "a hard cut joins with nothing")

  -- test_cyrillic_letters_are_never_split
  assertParts(MessageSplit.Split("яяя", 5), { "яя", "я" }, "cyrillic")

  -- test_cjk_letters_are_never_split
  assertParts(MessageSplit.Split("中中中", 4), { "中", "中", "中" }, "cjk")

  local link = "|Hitem:19019::::::::60:::::::::|h[Thunderfury]|h"

  -- test_hyperlink_is_kept_whole
  assertParts(MessageSplit.Split("xxxxx" .. link, #link), { "xxxxx", link }, "link")

  -- test_coloured_hyperlink_is_kept_whole
  local coloured = "|cffa335ee" .. link .. "|r"
  assertParts(MessageSplit.Split("xxxxx" .. coloured, #coloured), { "xxxxx", coloured }, "coloured link")

  -- test_named_colour_hyperlink_is_kept_whole
  local named = "|cnIQ4:" .. link .. "|r"
  assertParts(MessageSplit.Split("xxxxx" .. named, #named), { "xxxxx", named }, "named colour link")

  -- test_unit_longer_than_a_part_goes_alone
  assertParts(MessageSplit.Split("ab" .. link .. "cd", 20), { "ab", link, "cd" }, "oversized unit")

  -- test_space_after_a_unit_longer_than_a_part_becomes_the_join
  local afterLink = MessageSplit.Split(link .. " " .. string.rep("b", 20), 20)
  assertParts(afterLink, { link, string.rep("b", 20) }, "space after oversized unit")
  assert(afterLink[2].join == " ", "the space after the oversized unit is the join")

  -- test_leading_whitespace_is_never_an_empty_part
  assertParts(MessageSplit.Split("  " .. string.rep("b", 10), 6), { "  bbbb", "bbbbbb" }, "leading whitespace")

  -- test_colour_run_may_span_parts
  assertParts(MessageSplit.Split("|cffff0000aaaa bbbb cccc|r", 20), { "|cffff0000aaaa bbbb", "cccc|r" }, "colour run")

  -- test_colour_token_is_kept_whole
  assertParts(MessageSplit.Split("xxxxxxxx|cffff0000yy", 12), { "xxxxxxxx", "|cffff0000yy" }, "colour token")

  -- test_colour_reset_is_kept_whole
  assertParts(MessageSplit.Split("xxxx|r", 5), { "xxxx", "|r" }, "colour reset")

  -- test_texture_is_kept_whole
  local texture = "|TInterface\\Icons\\INV_Misc_QuestionMark:16|t"
  assertParts(MessageSplit.Split("xxxx" .. texture, #texture), { "xxxx", texture }, "texture")

  -- test_atlas_is_kept_whole
  local atlas = "|A:raceicon-human-male:16:16|a"
  assertParts(MessageSplit.Split("xxxx" .. atlas, #atlas), { "xxxx", atlas }, "atlas")

  -- test_battle_net_name_token_is_kept_whole
  assertParts(MessageSplit.Split("xxxx|Kq12|k", 7), { "xxxx", "|Kq12|k" }, "BNet token")

  -- test_escaped_pipe_is_kept_whole
  assertParts(MessageSplit.Split("xxxx||", 5), { "xxxx", "||" }, "escaped pipe")

  -- test_newline_escape_is_kept_whole
  assertParts(MessageSplit.Split("xxxx|n", 5), { "xxxx", "|n" }, "newline escape")

  -- test_classic_wire_quest_link_is_kept_whole
  assertParts(MessageSplit.Split("xxxx[Hogger (176)]", 16), { "xxxx", "[Hogger (176)]" }, "classic quest link")

  local words = { "the", "quick", "brown", "fox", "jumps", "over", "a", "lazy", "dog" }
  local prose = words[1]
  local wordIndex = 1
  while true do
    wordIndex = wordIndex % #words + 1
    local longer = prose .. " " .. words[wordIndex]
    if #longer > 799 then
      break
    end
    prose = longer
  end

  -- test_full_length_prose_fits_in_four_whisper_parts
  assert(#prose >= 790 and #prose <= 799, "prose fixture is near the cap")
  assert(MessageSplit.Count(prose, 255) <= 4, "799 bytes of prose needs at most 4 parts")

  -- test_link_heavy_text_counts_five_parts
  local retailLink = "|cnIQ4:|Hitem:212395::::::::80:577::6:4:10354:10255:1540:10876:1:28:2462:::::|h"
    .. "[Algari Competitor's Cloth Hands of the Aspects]|h|r"
  local heavy = table.concat({ retailLink, retailLink, retailLink, retailLink, retailLink }, " ")
  assert(#heavy <= 799, "link fixture is under the byte cap")
  assert(MessageSplit.Count(heavy, 255) == 5, "one long link per part needs 5 parts")

  -- test_count_matches_the_number_of_split_parts
  local samples = { "", "hi", prose, heavy, string.rep("a", 300), "яяя中中 " .. link .. " ||xx|n" }
  for _, sample in ipairs(samples) do
    for _, partBytes in ipairs({ 5, 20, 255 }) do
      local split = MessageSplit.Split(sample, partBytes)
      assert(MessageSplit.Count(sample, partBytes) == #split, "count " .. partBytes .. " [" .. sample .. "]")
    end
  end

  -- test_joining_parts_rebuilds_the_text
  local rebuilt = {}
  for _, part in ipairs(MessageSplit.Split(prose, 255)) do
    rebuilt[#rebuilt + 1] = (part.join or "") .. part.text
  end
  assert(table.concat(rebuilt) == prose, "parts and joins rebuild the original text")
end
