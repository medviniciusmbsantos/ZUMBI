--!strict
-- Pure rules: no Roblox globals. Keep all damage/economy decisions on the server.
local Balance = {}

Balance.MaxPlayers = 6
Balance.FinalWave = 15
Balance.InitialPrep = 40
Balance.BetweenWaves = 18
Balance.ExtractionTime = 45
Balance.MaxLivingZombies = 36
Balance.StartingCoins = 120
Balance.KillCoins = 12
Balance.AssistCoins = 5
Balance.WaveCoins = 35
Balance.ExtractionCoins = 300
Balance.UpgradeCost = 280
Balance.MysteryCost = 0 -- Free random supplies only; never sell random rewards.
Balance.BaseSpeed = 16
Balance.SprintSpeed = 23

Balance.Weapons = {
	Pistol = { Name = "Sentinela .45", Price = 0, Damage = 26, Magazine = 12, Reserve = 108, Interval = 0.24, Reload = 1.55, Pellets = 1, Spread = 0.008, Range = 320, Automatic = false, Color = { 185, 194, 207 } },
	SMG = { Name = "Vespa SMG", Price = 220, Damage = 19, Magazine = 30, Reserve = 210, Interval = 0.085, Reload = 1.9, Pellets = 1, Spread = 0.025, Range = 250, Automatic = true, Color = { 90, 210, 185 } },
	Shotgun = { Name = "Escopeta Ruptura", Price = 360, Damage = 16, Magazine = 6, Reserve = 54, Interval = 0.8, Reload = 2.5, Pellets = 8, Spread = 0.085, Range = 140, Automatic = false, Color = { 220, 155, 75 } },
	Rifle = { Name = "AR Aurora", Price = 480, Damage = 38, Magazine = 24, Reserve = 168, Interval = 0.14, Reload = 2.2, Pellets = 1, Spread = 0.012, Range = 450, Automatic = true, Color = { 230, 100, 95 } },
}

Balance.Skins = {
	Default = { Name = "Aço", Price = 0, Color = { 185, 194, 207 } },
	Ember = { Name = "Brasa", Price = 400, Color = { 255, 112, 45 } },
	Arctic = { Name = "Ártico", Price = 650, Color = { 110, 225, 255 } },
	Toxic = { Name = "Contágio", Price = 900, Color = { 165, 255, 75 } },
	Violet = { Name = "Anomalia", Price = 1200, Color = { 193, 125, 255 } },
}

Balance.Perks = {
	Juggernaut = { Name = "Titã", Price = 320, Description = "+75 de vida máxima nesta partida" },
	QuickHands = { Name = "Mãos rápidas", Price = 240, Description = "Recarga 35% mais rápida nesta partida" },
	Runner = { Name = "Corredor", Price = 200, Description = "+3 de velocidade nesta partida" },
}

function Balance.wave(wave: number, players: number)
	wave = math.max(1, math.floor(wave))
	players = math.clamp(math.floor(players), 1, Balance.MaxPlayers)
	return {
		Count = 5 + wave * 3 + (players - 1) * 4,
		Health = math.floor(75 * (1 + (wave - 1) * 0.17)),
		Damage = math.min(34, 9 + wave),
		Speed = math.min(18, 9 + wave * 0.45),
		SpawnInterval = math.max(0.38, 1.35 - wave * 0.055),
		Boss = wave % 5 == 0,
	}
end

function Balance.killReward(wave: number, boosted: boolean): number
	return (Balance.KillCoins + math.floor(wave / 3)) * (if boosted then 2 else 1)
end

function Balance.upgradeDamage(base: number, tier: number): number
	return base * (1 + math.clamp(tier, 0, 3) * 0.45)
end

function Balance.refillCost(price: number): number
	return math.max(35, math.floor(price * 0.22))
end

return Balance
