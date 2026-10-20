local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.ZumbiShared.Config)
local Data = require(script.Parent.DataService)

local Commerce = { Catalog = {}, OnPassChanged = nil }
local productsById = {}

function Commerce.refreshPass(player, attempt)
	local owned = false
	if Config.VanguardPassId > 0 then
		local ok, result = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.VanguardPassId) end)
		if not ok then
			-- A network error must not revoke a pass already verified this session.
			if player.Parent and (attempt or 1) < 3 then
				task.delay(8, function() if player.Parent then Commerce.refreshPass(player, (attempt or 1) + 1) end end)
			end
			return
		end
		owned = result
	end
	if not player.Parent then return end
	player:SetAttribute("Vanguard", owned)
	if Commerce.OnPassChanged then Commerce.OnPassChanged(player) end
end

function Commerce.sendCatalog(player, remote)
	remote:FireClient(player, "Catalog", Commerce.Catalog)
end

function Commerce.start(effects, onPassChanged)
	Commerce.OnPassChanged = onPassChanged
	for _, product in Config.Products do
		assert(product.Id == 0 or not productsById[product.Id], "Developer Product IDs must be unique")
		if product.Id > 0 then productsById[product.Id] = product end
	end
	MarketplaceService.ProcessReceipt = function(receipt)
		local product = productsById[receipt.ProductId]
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not product then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if Data.receipt(player, tostring(receipt.PurchaseId), product) then
			effects:FireClient(player, "Toast", { Text = "Compra entregue e salva: " .. product.Name, Good = true })
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
		if purchased and id == Config.VanguardPassId then task.spawn(Commerce.refreshPass, player) end
	end)
	task.spawn(function()
		for _, product in Config.Products do
			local entry = { Id = product.Id, Key = product.Key, Name = product.Name, Description = product.Description, Kind = "Product", Available = false }
			if product.Id > 0 then
				local ok, info = pcall(function() return MarketplaceService:GetProductInfo(product.Id, Enum.InfoType.Product) end)
				if ok and info.IsForSale and info.PriceInRobux then entry.Available, entry.Price = true, info.PriceInRobux end
			end
			table.insert(Commerce.Catalog, entry)
		end
		local pass = { Id = Config.VanguardPassId, Key = "Vanguard", Name = Config.VanguardName,
			Description = "+25 vida base e +2 velocidade • permanente", Kind = "Pass", Available = false }
		if pass.Id > 0 then
			local ok, info = pcall(function() return MarketplaceService:GetProductInfo(pass.Id, Enum.InfoType.GamePass) end)
			if ok and info.IsForSale and info.PriceInRobux then pass.Available, pass.Price = true, info.PriceInRobux end
		end
		table.insert(Commerce.Catalog, pass)
		effects:FireAllClients("Catalog", Commerce.Catalog)
	end)
end

return Commerce
