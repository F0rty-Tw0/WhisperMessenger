local Identity = require("WhisperMessenger.Model.Identity")

return function()
  local contact = Identity.FromWhisper("Arthas-Area52", "Player-3676-0ABCDEF0")
  assert(contact.channel == "WOW")
  assert(contact.contactKey == "WOW::arthas-area52")
  assert(contact.displayName == "Arthas-Area52")
  assert(contact.guid == "Player-3676-0ABCDEF0")
end
