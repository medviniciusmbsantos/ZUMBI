local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Util = require(script.Parent.Util)

local World = { Spawn = Vector3.new(0, 4, 80), Extraction = Vector3.new(0, 0.4, 132), Doors = {}, Loot = {}, Powered = false }
local rng = Random.new(8137)
local palette = { concrete = Color3.fromRGB(67, 73, 77), brick = Color3.fromRGB(103, 72, 62), wood = Color3.fromRGB(91, 71, 51), glow = Color3.fromRGB(100, 230, 210) }

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.Concrete
	p.Parent = parent
	return p
end

local function label(anchor, text, color, size)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.StudsOffset = "Sign", UDim2.fromOffset(size or 240, 62), Vector3.new(0, 3, 0)
	gui.MaxDistance, gui.AlwaysOnTop, gui.Parent = 115, false, anchor
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Text = UDim2.fromScale(1, 1), 0.2, text
	t.BackgroundColor3, t.TextColor3, t.TextSize = Color3.fromRGB(13, 20, 23), color or Color3.fromRGB(235, 233, 216), 17
	t.Font, t.TextWrapped, t.Parent = Enum.Font.GothamBold, true, gui
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 5)
	return gui
end

function World.prompt(anchor, action, object, callback, duration)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = action, object
	prompt.MaxActivationDistance, prompt.HoldDuration = 10, duration or 0.35
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.RequiresLineOfSight, prompt.Parent = false, anchor
	local accept = Util.limiter(2, 2)
	prompt.Triggered:Connect(function(player)
		if prompt.Enabled and player:GetAttribute("InRound") and accept(player) and Util.near(player, anchor.Position, 13) then callback(player, prompt) end
	end)
	return prompt
end

local function lamp(parent, pos, color)
	part(parent, "Poste", Vector3.new(0.6, 16, 0.6), CFrame.new(pos + Vector3.new(0, 8, 0)), palette.concrete, Enum.Material.Metal)
	local bulb = part(parent, "Luz", Vector3.new(3, 0.4, 3), CFrame.new(pos + Vector3.new(0, 16, 0)), color, Enum.Material.Neon)
	local light = Instance.new("PointLight"); light.Color, light.Range, light.Brightness, light.Parent = color, 34, 1.5, bulb
end

local function furnishing(parent, kind, pos)
	local cf = CFrame.new(pos)
	if kind == "bench" then
		part(parent, "Banco", Vector3.new(12, 0.7, 3), cf * CFrame.new(0, 2, 0), palette.wood, Enum.Material.WoodPlanks)
		part(parent, "Encosto", Vector3.new(12, 3, 0.6), cf * CFrame.new(0, 3, -1.3), palette.wood, Enum.Material.WoodPlanks)
		for _, x in { -5, 5 } do part(parent, "Pé", Vector3.new(0.6, 2, 2), cf * CFrame.new(x, 1, 0), palette.concrete, Enum.Material.Metal) end
	elseif kind == "desk" then
		part(parent, "Mesa", Vector3.new(10, 0.7, 5), cf * CFrame.new(0, 3, 0), palette.wood, Enum.Material.WoodPlanks)
		for _, x in { -4, 4 } do part(parent, "Suporte", Vector3.new(0.7, 3, 4), cf * CFrame.new(x, 1.5, 0), palette.concrete) end
		part(parent, "Terminal", Vector3.new(3, 2, 0.5), cf * CFrame.new(0, 4.3, -1), Color3.fromRGB(30, 85, 80), Enum.Material.Neon)
	elseif kind == "bed" then
		part(parent, "Maca", Vector3.new(5, 1, 9), cf * CFrame.new(0, 2.6, 0), Color3.fromRGB(170, 190, 180), Enum.Material.Fabric)
		part(parent, "Base", Vector3.new(4, 2, 8), cf * CFrame.new(0, 1, 0), palette.concrete, Enum.Material.Metal)
	end
end

local function building(name, center, width, depth, height, color, locked, price, callback)
	local model = Instance.new("Model"); model.Name, model.Parent = name, World.Map
	local cf = CFrame.new(center)
	part(model, "Piso", Vector3.new(width, 0.4, depth), cf, Color3.fromRGB(92, 91, 83), Enum.Material.Slate)
	-- Front wall has a real, 12-stud-wide entrance. Side windows have actual openings.
	for _, s in { -1, 1 } do
		part(model, "Fachada", Vector3.new((width - 12) / 2, height, 1.2), cf * CFrame.new(s * (width + 12) / 4, height / 2, depth / 2), color)
		part(model, "JanelaBase", Vector3.new(1.2, 4, depth), cf * CFrame.new(s * width / 2, 2, 0), color)
		part(model, "JanelaTopo", Vector3.new(1.2, height - 9, depth), cf * CFrame.new(s * width / 2, 9 + (height - 9) / 2, 0), color)
		for z = -depth / 2, depth / 2, 14 do part(model, "Coluna", Vector3.new(1.4, 5, 2.5), cf * CFrame.new(s * width / 2, 6.5, z), color) end
	end
	part(model, "Portal", Vector3.new(12, height - 10, 1.2), cf * CFrame.new(0, 10 + (height - 10) / 2, depth / 2), color)
	part(model, "ParedeFundo", Vector3.new(width, height, 1.2), cf * CFrame.new(0, height / 2, -depth / 2), color)
	part(model, "Telhado", Vector3.new(width + 3, 1.2, depth + 3), cf * CFrame.new(0, height + 0.6, 0), Color3.fromRGB(36, 43, 46), Enum.Material.Slate)
	local sign = part(model, "Placa", Vector3.new(math.min(width - 4, 30), 3, 0.7), cf * CFrame.new(0, 12, depth / 2 + 1), palette.concrete)
	label(sign, string.upper(name), palette.glow)
	local light = Instance.new("PointLight"); light.Range, light.Brightness, light.Color, light.Parent = 55, 1.3, Color3.fromRGB(220, 205, 160), sign
	if locked then
		local door = part(model, "Porta", Vector3.new(12, 10, 1), cf * CFrame.new(0, 5, depth / 2), palette.wood, Enum.Material.WoodPlanks)
		local d = { part = door, cf = door.CFrame, open = false }
		d.prompt = World.prompt(door, "Desbloquear • " .. price .. " moedas", name, function(player)
			if d.open then return end
			if callback(player, "Door", { Price = price, Name = name }) then
				d.open, d.prompt.Enabled = true, false
				door.CanCollide = false
				TweenService:Create(door, TweenInfo.new(0.7), { CFrame = d.cf * CFrame.new(0, 11, 0), Transparency = 0.7 }):Play()
			end
		end)
		table.insert(World.Doors, d)
	end
	return model
end

local function station(parent, pos, title, action, kind, arg, callback, color)
	local p = part(parent, title, Vector3.new(4, 5, 3), CFrame.new(pos + Vector3.new(0, 2.5, 0)), color or palette.glow, Enum.Material.Metal)
	part(parent, "Painel", Vector3.new(3.3, 1.7, 0.15), p.CFrame * CFrame.new(0, 0.8, 1.6), palette.glow, Enum.Material.Neon)
	label(p, title)
	World.prompt(p, action, title, function(player) callback(player, kind, arg) end)
	return p
end

local function plane(parent, cf)
	local m = Instance.new("Model"); m.Name, m.Parent = "Voo 813", parent
	part(m, "Fuselagem", Vector3.new(10, 9, 50), cf, Color3.fromRGB(178, 183, 172), Enum.Material.Metal)
	part(m, "Faixa", Vector3.new(10.1, 1.3, 45), cf * CFrame.new(0, 1, 0), Color3.fromRGB(41, 118, 114), Enum.Material.Metal)
	part(m, "Asas", Vector3.new(68, 1, 13), cf * CFrame.new(0, -2, 1), Color3.fromRGB(117, 128, 134), Enum.Material.Metal)
	part(m, "Cauda", Vector3.new(2, 17, 10), cf * CFrame.new(0, 7, 20), Color3.fromRGB(57, 105, 108), Enum.Material.Metal)
	for _, x in { -19, 19 } do
		local engine = part(m, "Motor", Vector3.new(6, 6, 12), cf * CFrame.new(x, -4, -2), palette.concrete, Enum.Material.Metal)
		engine.Shape = Enum.PartType.Cylinder
	end
	for z = -18, 14, 6 do
		for _, x in { -5.1, 5.1 } do part(m, "Janela", Vector3.new(0.15, 2, 2), cf * CFrame.new(x, 1.7, z), Color3.fromRGB(28, 46, 52), Enum.Material.Glass) end
	end
	return m
end

function World.build(callback)
	local previous = workspace:FindFirstChild("ZumbiWorld"); if previous then previous:Destroy() end
	World.Map = Instance.new("Folder"); World.Map.Name, World.Map.Parent = "ZumbiWorld", workspace
	World.Enemies = Util.folder(workspace, "ZumbiEnemies")
	World.Drops = Util.folder(workspace, "ZumbiDrops")
	Lighting.ClockTime, Lighting.Brightness = 0.6, 2
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(69, 85, 100), Color3.fromRGB(85, 100, 115)
	Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = Color3.fromRGB(32, 53, 60), 120, 480
	local atmosphere = Instance.new("Atmosphere"); atmosphere.Density, atmosphere.Haze, atmosphere.Color, atmosphere.Parent = 0.25, 1.5, Color3.fromRGB(141, 166, 163), Lighting
	part(World.Map, "Terreno", Vector3.new(550, 4, 550), CFrame.new(0, -2, 0), Color3.fromRGB(45, 58, 48), Enum.Material.Grass)
	for _, data in { { 0, 0, 28, 470 }, { 0, 55, 470, 26 }, { 0, -100, 470, 22 } } do
		part(World.Map, "Asfalto", Vector3.new(data[3], 0.15, data[4]), CFrame.new(data[1], 0.05, data[2]), Color3.fromRGB(42, 46, 48), Enum.Material.Asphalt)
	end
	for z = -210, 210, 18 do part(World.Map, "Faixa", Vector3.new(0.6, 0.05, 7), CFrame.new(0, 0.16, z), Color3.fromRGB(180, 166, 112)) end
	for _, x in { -260, 260 } do part(World.Map, "Limite", Vector3.new(5, 44, 530), CFrame.new(x, 20, 0), palette.concrete, Enum.Material.Rock) end
	for _, z in { -260, 260 } do part(World.Map, "Limite", Vector3.new(530, 44, 5), CFrame.new(0, 20, z), palette.concrete, Enum.Material.Rock) end
	for _, x in { -24, 24 } do for z = -200, 180, 80 do lamp(World.Map, Vector3.new(x, 0, z), Color3.fromRGB(200, 184, 134)) end end

	local church = building("Igreja da Aurora", Vector3.new(-112, 0.3, -30), 64, 80, 26, Color3.fromRGB(102, 98, 85), true, 100, callback)
	for _, x in { -17, 17 } do for z = -48, -5, 14 do furnishing(church, "bench", Vector3.new(-112 + x, 0.5, z)) end end
	part(church, "Altar", Vector3.new(20, 3, 7), CFrame.new(-112, 1.8, -60), palette.concrete)
	part(church, "Torre", Vector3.new(13, 24, 13), CFrame.new(-112, 38, -5), Color3.fromRGB(95, 92, 82))
	part(church, "CruzV", Vector3.new(1.3, 10, 1.3), CFrame.new(-112, 55, -5), palette.glow, Enum.Material.Neon)
	part(church, "CruzH", Vector3.new(7, 1.3, 1.3), CFrame.new(-112, 57, -5), palette.glow, Enum.Material.Neon)
	station(church, Vector3.new(-88, 0.6, -55), "TITÃ • 320", "Obter buff", "Perk", "Juggernaut", callback, Color3.fromRGB(165, 65, 67))
	station(church, Vector3.new(-136, 0.6, -55), "REANIMADOR • 90", "Comprar resgate para a partida", "RoundRevive", nil, callback)

	local police = building("Delegacia", Vector3.new(110, 0.3, -28), 70, 70, 19, Color3.fromRGB(68, 88, 106), true, 130, callback)
	for _, x in { 92, 125 } do furnishing(police, "desk", Vector3.new(x, 0.6, -20)) end
	for x = 86, 112, 4 do part(police, "Cela", Vector3.new(0.4, 10, 0.4), CFrame.new(x, 5, -48), palette.concrete, Enum.Material.Metal) end
	station(police, Vector3.new(135, 0.6, -50), "AR AURORA • 480", "Comprar / reabastecer", "Weapon", "Rifle", callback)
	station(police, Vector3.new(82, 0.6, -50), "MÃOS RÁPIDAS • 240", "Obter buff", "Perk", "QuickHands", callback, Color3.fromRGB(100, 125, 190))

	local hospital = building("Hospital", Vector3.new(128, 0.3, -165), 64, 62, 19, Color3.fromRGB(129, 141, 132), false, 0, callback)
	for _, x in { 111, 145 } do for _, z in { -180, -155 } do furnishing(hospital, "bed", Vector3.new(x, 0.6, z)) end end
	station(hospital, Vector3.new(128, 0.6, -188), "POSTO MÉDICO • 60", "Recuperar vida", "Heal", nil, callback, Color3.fromRGB(191, 77, 81))
	local cross = part(hospital, "CruzHospital", Vector3.new(3, 9, 0.6), CFrame.new(128, 16, -132), Color3.fromRGB(255, 100, 100), Enum.Material.Neon)
	part(hospital, "CruzHorizontal", Vector3.new(9, 3, 0.6), cross.CFrame, cross.Color, Enum.Material.Neon)

	local garage = building("Oficina", Vector3.new(-128, 0.3, 103), 68, 55, 19, palette.brick, false, 0, callback)
	station(garage, Vector3.new(-148, 0.6, 87), "APRIMORADOR • 280 / NÍVEL", "Aprimorar arma equipada", "Upgrade", nil, callback, Color3.fromRGB(183, 126, 47))
	station(garage, Vector3.new(-110, 0.6, 87), "VESPA SMG • 220", "Comprar / reabastecer", "Weapon", "SMG", callback)
	furnishing(garage, "desk", Vector3.new(-128, 0.6, 102))
	local market = building("Mercado", Vector3.new(130, 0.3, 105), 65, 58, 18, palette.brick, false, 0, callback)
	for _, x in { 112, 146 } do
		for _, y in { 2, 4, 6 } do part(market, "Prateleira", Vector3.new(4, 0.5, 26), CFrame.new(x, y, 100), palette.wood, Enum.Material.WoodPlanks) end
	end
	station(market, Vector3.new(130, 0.6, 87), "CORREDOR • 200", "Obter buff", "Perk", "Runner", callback, Color3.fromRGB(60, 166, 151))
	station(market, Vector3.new(130, 0.6, 116), "ESCOPETA • 360", "Comprar / reabastecer", "Weapon", "Shotgun", callback)
	local depot = building("Central de energia", Vector3.new(0, 0.3, -183), 56, 52, 18, palette.concrete, true, 170, callback)
	World.PowerPanel = station(depot, Vector3.new(0, 0.6, -197), "GERADOR • 180", "Ligar energia da cidade", "Power", nil, callback, Color3.fromRGB(207, 161, 50))
	for _, x in { -17, 17 } do part(depot, "Gerador", Vector3.new(9, 9, 17), CFrame.new(x, 4.8, -183), palette.concrete, Enum.Material.Metal) end
	station(World.Map, Vector3.new(27, 0.5, -18), "ARMADILHA • 80", "Descarga elétrica • 12s", "Trap", nil, callback)
	station(World.Map, Vector3.new(-29, 0.5, 34), "RESGATE GRÁTIS • 1 / HORDA", "Pistola / SMG / escopeta / AR • 25% cada", "Mystery", nil, callback, Color3.fromRGB(125, 82, 153))

	-- Cemetery: gates, aisles, tombstones, and a small enterable crypt.
	local cemetery = Instance.new("Folder"); cemetery.Name, cemetery.Parent = "Cemitério", World.Map
	for _, x in { -175, -70 } do part(cemetery, "Muro", Vector3.new(2, 5, 92), CFrame.new(x, 2.5, -176), palette.concrete) end
	part(cemetery, "Muro", Vector3.new(107, 5, 2), CFrame.new(-122, 2.5, -222), palette.concrete)
	for _, x in { -160, -137, -110, -86 } do
		for _, z in { -200, -177, -151 } do
			part(cemetery, "Sepultura", Vector3.new(5, 0.4, 9), CFrame.new(x, 0.3, z), Color3.fromRGB(69, 66, 54), Enum.Material.Ground)
			local stone = part(cemetery, "Lápide", Vector3.new(4, 5, 0.8), CFrame.new(x, 2.5, z - 4), Color3.fromRGB(118, 126, 117), Enum.Material.Slate)
			part(cemetery, "Inscrição", Vector3.new(2.6, 0.3, 0.1), stone.CFrame * CFrame.new(0, 0.5, 0.45), palette.concrete)
		end
	end
	local crypt = building("Cripta", Vector3.new(-202, 0.3, -177), 30, 42, 13, palette.concrete, false, 0, callback)
	station(crypt, Vector3.new(-202, 0.6, -190), "MUNIÇÃO • 45", "Reabastecer arma equipada", "Ammo", nil, callback)
	local gate = part(cemetery, "Entrada", Vector3.new(18, 1, 1), CFrame.new(-123, 12, -129), palette.concrete)
	label(gate, "CEMITÉRIO • NÃO OLHE PARA TRÁS")

	World.Wreck = plane(World.Map, CFrame.new(-19, 5, 165) * CFrame.Angles(0, math.rad(22), math.rad(7)))
	local fire = Instance.new("Fire"); fire.Size, fire.Heat, fire.Parent = 14, 9, World.Wreck.Fuselagem
	local smoke = Instance.new("Smoke"); smoke.Size, smoke.Opacity, smoke.RiseVelocity, smoke.Parent = 15, 0.35, 10, World.Wreck.Fuselagem
	for _ = 1, 16 do
		part(World.Map, "Destroço", Vector3.new(rng:NextNumber(1, 4), 0.6, rng:NextNumber(2, 8)), CFrame.new(rng:NextNumber(-70, 40), 0.7, rng:NextNumber(140, 205)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), palette.concrete, Enum.Material.Metal)
	end
	local helipad = part(World.Map, "ZonaDeExtração", Vector3.new(25, 0.25, 25), CFrame.new(World.Extraction), Color3.fromRGB(45, 85, 80), Enum.Material.Metal)
	label(helipad, "EXTRAÇÃO\nSobreviva às 15 hordas", palette.glow)
	World.Helipad = helipad
	local spawn = Instance.new("SpawnLocation"); spawn.Name, spawn.Size, spawn.CFrame = "Acampamento", Vector3.new(12, 0.3, 12), CFrame.new(0, 0.5, 80)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency, spawn.Parent = true, true, 0, 1, World.Map
	station(World.Map, Vector3.new(20, 0.5, 82), "PISTOLA • GRÁTIS / RECARGA 35", "Comprar / reabastecer", "Weapon", "Pistol", callback)

	for _, pos in { Vector3.new(-128, 1.6, -14), Vector3.new(120, 1.6, -12), Vector3.new(140, 1.6, -180), Vector3.new(-155, 1.6, -170), Vector3.new(-120, 1.6, 112), Vector3.new(147, 1.6, 115), Vector3.new(40, 1.6, 170), Vector3.new(-205, 1.6, -170), Vector3.new(10, 1.6, -175), Vector3.new(48, 1.6, -88) } do
		local box = part(World.Map, "Suprimentos", Vector3.new(4, 3, 3), CFrame.new(pos), Color3.fromRGB(119, 131, 65), Enum.Material.Metal)
		local item = { part = box, used = false }
		item.prompt = World.prompt(box, "Vasculhar", "Suprimentos • 1 uso por horda", function(player)
			if item.used then return end
			if callback(player, "Loot", nil) then
				item.used, item.prompt.Enabled, box.Color = true, false, palette.concrete
			end
		end, 0.8)
		table.insert(World.Loot, item)
	end

	-- A repair interaction rewards exploration without supplying infinite coins.
	for _, pos in { Vector3.new(-80, 3, -29), Vector3.new(75, 3, -25), Vector3.new(162, 3, 105) } do
		local plank = part(World.Map, "Barricada", Vector3.new(1.5, 1.2, 12), CFrame.new(pos) * CFrame.Angles(math.rad(12), 0, 0), palette.wood, Enum.Material.WoodPlanks)
		World.prompt(plank, "Reparar • +20 moedas", "Barricada • uma vez por horda / jogador", function(player) callback(player, "Repair", plank) end, 1.3)
	end
	for i = 1, 36 do
		local angle = i * math.pi * 2 / 36
		local pos = Vector3.new(math.cos(angle) * 235, 0, math.sin(angle) * 235)
		part(World.Map, "Tronco", Vector3.new(3, 15, 3), CFrame.new(pos + Vector3.new(0, 7.5, 0)), palette.wood, Enum.Material.Wood)
		local crown = part(World.Map, "Copa", Vector3.new(16, 19, 16), CFrame.new(pos + Vector3.new(0, 19, 0)), Color3.fromRGB(31, 53, 46), Enum.Material.Grass)
		crown.Shape = Enum.PartType.Ball
	end
	World.SpawnPoints = {}
	for _, p in { { -225, 30 }, { 220, 25 }, { -220, 145 }, { 215, 160 }, { -45, -240 }, { 45, -240 }, { 215, -95 }, { -220, -80 }, { 100, 220 }, { -110, 220 } } do
		table.insert(World.SpawnPoints, Vector3.new(p[1], 4, p[2]))
	end
end

function World.resetLoot()
	for _, item in World.Loot do item.used, item.prompt.Enabled, item.part.Color = false, true, Color3.fromRGB(119, 131, 65) end
end

function World.reset()
	World.Powered = false
	World.PowerPanel.Color = Color3.fromRGB(207, 161, 50)
	World.Helipad.Color = Color3.fromRGB(45, 85, 80)
	if World.Helicopter then World.Helicopter:Destroy(); World.Helicopter = nil end
	for _, d in World.Doors do
		d.open, d.prompt.Enabled, d.part.CanCollide, d.part.Transparency, d.part.CFrame = false, true, true, 0, d.cf
	end
	World.resetLoot()
	World.Drops:ClearAllChildren()
end

function World.crash()
	local cf = CFrame.new(-19, 5, 165) * CFrame.Angles(0, math.rad(22), math.rad(7))
	local flying = plane(World.Map, cf + Vector3.new(-145, 100, 90))
	for _, p in flying:GetChildren() do if p:IsA("BasePart") then p.CanCollide = false end end
	local value = Instance.new("CFrameValue"); value.Value = flying:GetPivot()
	local connection = value.Changed:Connect(function(pivot) flying:PivotTo(pivot) end)
	TweenService:Create(value, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = cf }):Play()
	task.delay(4, function()
		connection:Disconnect(); value:Destroy(); flying:Destroy()
		local explosion = Instance.new("Explosion"); explosion.Position, explosion.BlastRadius, explosion.BlastPressure = cf.Position, 22, 0
		explosion.DestroyJointRadiusPercent, explosion.Parent = 0, workspace
	end)
end

function World.extraction()
	World.Helipad.Color = Color3.fromRGB(75, 255, 175)
	local heli = Instance.new("Model"); heli.Name, heli.Parent = "Resgate", World.Map
	World.Helicopter = heli
	part(heli, "Cabine", Vector3.new(9, 7, 16), CFrame.new(0, 9, 132), Color3.fromRGB(42, 74, 65), Enum.Material.Metal)
	part(heli, "Vidro", Vector3.new(7, 4, 0.5), CFrame.new(0, 9, 123.8), Color3.fromRGB(78, 160, 167), Enum.Material.Glass)
	part(heli, "Cauda", Vector3.new(3, 3, 18), CFrame.new(0, 10, 147), palette.concrete, Enum.Material.Metal)
	local rotor = part(heli, "Rotor", Vector3.new(37, 0.3, 2), CFrame.new(0, 14, 132), palette.concrete, Enum.Material.Metal)
	rotor.CanCollide = false
	for _, x in { -6, 6 } do part(heli, "Patim", Vector3.new(0.6, 0.6, 20), CFrame.new(x, 5, 132), palette.concrete, Enum.Material.Metal) end
	task.spawn(function()
		while heli.Parent do rotor.CFrame *= CFrame.Angles(0, 0.65, 0); task.wait(0.04) end
	end)
end

function World.drop(position, callback)
	local p = part(World.Drops, "Munição caída", Vector3.new(2, 1.3, 2), CFrame.new(position.X, 1, position.Z), palette.glow, Enum.Material.Neon)
	World.prompt(p, "Coletar munição", "Suprimentos de infectado", function(player)
		if not p.Parent then return end
		p:Destroy(); callback(player)
	end, 0)
	Debris:AddItem(p, 35)
end

return World
