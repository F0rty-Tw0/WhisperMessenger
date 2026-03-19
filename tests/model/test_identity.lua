local Identity = require("WhisperMessenger.Model.Identity")

return function()
  local contact = Identity.FromWhisper("Arthas-Area52", "Player-3676-0ABCDEF0")
  assert(contact.channel == "WOW")
  assert(contact.contactKey == "WOW::arthas-area52")
  assert(contact.displayName == "Arthas-Area52")
  assert(contact.guid == "Player-3676-0ABCDEF0")

  local bnetContact = Identity.FromBattleNet(99, {
    battleTag = "Jaina#1234",
    accountName = "Jaina",
    gameAccountInfo = {
      characterName = "Jaina",
      realmName = "Proudmoore",
      playerGuid = "Player-60-0ABCDE123",
    },
  })

  assert(bnetContact.channel == "BN")
  assert(bnetContact.contactKey == "BN::99")
  assert(bnetContact.displayName == "Jaina#1234")
  assert(bnetContact.bnetAccountID == 99)
  assert(bnetContact.gameAccountName == "Jaina-Proudmoore")
  assert(bnetContact.guid == "Player-60-0ABCDE123")
end
