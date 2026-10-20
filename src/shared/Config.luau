-- Replace zeros only after publishing and creating products in Creator Dashboard.
-- IDs are public configuration, never credentials. Do NOT put API keys here.
return {
	DataStoreName = "ZumbiUltimoVoo_v1",
	Products = {
		{ Key = "CoinsSmall", Id = 0, Name = "500 suprimentos", Description = "Crédito permanente de 500 moedas", Grant = "Coins", Amount = 500 },
		{ Key = "CoinsLarge", Id = 0, Name = "1.800 suprimentos", Description = "Crédito permanente de 1.800 moedas", Grant = "Coins", Amount = 1800 },
		{ Key = "Revive", Id = 0, Name = "Resgate pessoal", Description = "+1 resgate; use quando eliminado durante uma horda", Grant = "Revives", Amount = 1 },
		{ Key = "DoubleCoins", Id = 0, Name = "Suprimentos em dobro", Description = "2× moedas de abates por 15 minutos de relógio", Grant = "Boost", Amount = 900 },
	},
	VanguardPassId = 0, -- +25 base health and +2 movement speed; all maps/weapons remain accessible.
	VanguardName = "Passe Vanguarda",
}
