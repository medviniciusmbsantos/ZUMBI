local Balance = require("../src/shared/Balance")
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local lastHealth, lastCount = 0, 0
for wave = 1, Balance.FinalWave do
	local solo = Balance.wave(wave, 1)
	local team = Balance.wave(wave, 6)
	check(solo.Health > lastHealth, "Health must scale every wave")
	check(solo.Count > lastCount, "Wave size must increase")
	check(team.Count > solo.Count, "Teams must face more zombies")
	check(solo.Boss == (wave % 5 == 0), "Bosses must occur on 5/10/15")
	check(solo.SpawnInterval > 0, "Spawn interval must be positive")
	check(solo.Speed < Balance.SprintSpeed, "Players must be able to escape at a sprint")
	check(Balance.killReward(wave, true) == 2 * Balance.killReward(wave, false), "Boost is exactly 2x kills")
	lastHealth, lastCount = solo.Health, solo.Count
end
check(Balance.wave(0, 0).Count == Balance.wave(1, 1).Count, "Clamp invalid wave and team")
check(Balance.wave(1, 999).Count == Balance.wave(1, 6).Count, "Clamp max team")
check(Balance.MysteryCost == 0, "Random weapon crate must remain free")
for id, weapon in Balance.Weapons do
	check(weapon.Damage > 0 and weapon.Magazine > 0 and weapon.Reserve >= weapon.Magazine, id .. " ammunition/damage")
	check(weapon.Interval > 1 / 18, id .. " must fit the server remote rate limit")
	check(weapon.Reload > 0 and weapon.Range > 0, id .. " reload/range")
	check(Balance.upgradeDamage(weapon.Damage, 3) > weapon.Damage * 2, id .. " upgrade effectiveness")
	check(Balance.upgradeDamage(weapon.Damage, 99) == Balance.upgradeDamage(weapon.Damage, 3), "Max upgrade must clamp")
	check(Balance.refillCost(weapon.Price) >= 35, "Refill minimum")
end
check(Balance.Weapons.Pistol.Price == 0, "Basic loadout must be free")
check(Balance.StartingCoins >= 100, "Player can unlock the church at start")
print("PASS balance: " .. checks .. " assertions")
