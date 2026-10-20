local Profile = require("../src/shared/Profile")
local Balance = require("../src/shared/Balance")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

for _, value in { -1, 0 / 0, math.huge, -math.huge, 0.5, "100", {}, false } do
	check(not Profile.isInteger(value), "Invalid integer accepted")
end
check(Profile.isInteger(0) and Profile.isInteger(500), "Valid integers rejected")
local d = Profile.normalize(nil)
check(d.Coins == Balance.StartingCoins and d.Skins.Default, "Defaults")
local broken = Profile.normalize({ Coins = math.huge, Wins = -9, Kills = "x", Revives = 2.8, Skin = "unknown", Skins = { Ember = true, unknown = true }, Receipts = { good = true, bad = "true", [7] = true } })
check(broken.Coins == Balance.StartingCoins and broken.Wins == 0 and broken.Kills == 0 and broken.Revives == 2, "Malformed numeric fields")
check(broken.Skins.Ember and broken.Skins.unknown == nil and broken.Skin == "Default", "Owned skin validation")
check(broken.Receipts.good and broken.Receipts.bad == nil and broken.Receipts[7] == nil, "Receipt validation")
local cloned = Profile.copy(broken); cloned.Skins.Ember = nil
check(broken.Skins.Ember, "Deep-copy isolation")
check(not Profile.lockedByOther({ Session = { Id = "other" } }, "self", 100), "Malformed lease")
check(not Profile.lockedByOther({ Session = "bad" }, "self", 100), "Malformed session")
check(not Profile.lockedByOther({ Session = { Id = "other", Until = math.huge } }, "self", 100), "Infinite lease")
check(not Profile.lockedByOther({ Session = { Id = "other", Until = 99 } }, "self", 100), "Expired lease")
check(not Profile.lockedByOther({ Session = { Id = "self", Until = 101 } }, "self", 100), "Own lease")
check(Profile.lockedByOther({ Session = { Id = "other", Until = 101 } }, "self", 100), "Active lease")
check(Profile.credit(d, 10, 1), "Valid credit")
local coins, kills = d.Coins, d.Kills
check(not Profile.credit(d, 10, math.huge) and d.Coins == coins and d.Kills == kills, "Invalid credit is atomic")
check(not Profile.debit(d, 0 / 0) and d.Coins == coins, "NaN spending rejected")
check(not Profile.debit(d, coins + 1) and d.Coins == coins, "Overspending rejected")
check(Profile.debit(d, 10) and d.Coins == coins - 10, "Valid spending")
for _, product in { { Grant = "Coins", Amount = -1 }, { Grant = "Coins", Amount = math.huge }, { Grant = "Other", Amount = 10 }, { Grant = "Revives", Amount = 0 } } do
	check(not Profile.grant(d, product, 100), "Invalid entitlement accepted")
end
check(Profile.grant(d, { Grant = "Revives", Amount = 1 }, 100) and d.Revives == 1, "Revive entitlement")
check(Profile.grant(d, { Grant = "Boost", Amount = 900 }, 100) and d.BoostUntil == 1000, "New boost")
check(Profile.grant(d, { Grant = "Boost", Amount = 900 }, 200) and d.BoostUntil == 1900, "Stacked boost")
check(Profile.grant(d, { Grant = "Coins", Amount = 500 }, 100), "Coin entitlement")
print("PASS Profile: " .. checks .. " assertions")
