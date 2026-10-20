local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService = game:GetService("SocialService")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Balance = require(ReplicatedStorage:WaitForChild("ZumbiShared"):WaitForChild("Balance"))
local net = ReplicatedStorage:WaitForChild("ZumbiNetwork")
local state = ReplicatedStorage:WaitForChild("ZumbiState")
local effects = workspace:FindFirstChild("ZumbiLocalEffects") or Instance.new("Folder")
effects.Name, effects.Parent = "ZumbiLocalEffects", workspace

local colors = { bg = Color3.fromRGB(12, 20, 25), panel = Color3.fromRGB(20, 31, 38), line = Color3.fromRGB(52, 76, 82),
	text = Color3.fromRGB(237, 237, 223), sub = Color3.fromRGB(158, 183, 185), teal = Color3.fromRGB(92, 234, 201),
	gold = Color3.fromRGB(255, 202, 114), red = Color3.fromRGB(255, 111, 104) }
local touch = UserInputService.TouchEnabled
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ZumbiHUD", false, 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(instance, radius)
	local corner = Instance.new("UICorner"); corner.CornerRadius, corner.Parent = UDim.new(0, radius or 9), instance
end

local function frame(parent, size, pos, color)
	local f = Instance.new("Frame")
	f.Size, f.Position, f.BackgroundColor3, f.BackgroundTransparency = size, pos, color or colors.panel, 0.08
	f.BorderSizePixel, f.Parent = 0, parent
	rounded(f)
	return f
end

local function text(parent, value, size, pos, width, color)
	local label = Instance.new("TextLabel")
	label.Size, label.Position = UDim2.new(1, -(width or 24), 0, size + 8), pos or UDim2.fromOffset(12, 8)
	label.BackgroundTransparency, label.Text, label.TextColor3 = 1, value, color or colors.text
	label.TextSize, label.Font, label.TextXAlignment = size, Enum.Font.GothamMedium, Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function button(parent, caption, size, pos, callback, color)
	local b = Instance.new("TextButton")
	b.Size, b.Position, b.Text = size, pos, caption
	b.BackgroundColor3, b.TextColor3, b.Font, b.TextSize = color or colors.line, colors.text, Enum.Font.GothamBold, 13
	b.BorderSizePixel, b.AutoButtonColor, b.Parent = 0, true, parent
	rounded(b, 7)
	if callback then b.Activated:Connect(callback) end
	return b
end

local function stroke(object, color)
	local s = Instance.new("UIStroke"); s.Color, s.Transparency, s.Parent = color or colors.line, 0.25, object
	return s
end

local brand = text(gui, "Z U M B I", 25, UDim2.fromOffset(20, 14), 24, colors.text)
brand.Size = UDim2.fromOffset(210, 34)
local subtitle = text(gui, "Ú L T I M O  V O O  /  8 1 3", 10, UDim2.fromOffset(22, 50), 24, colors.teal)
subtitle.Size = UDim2.fromOffset(260, 22)

local wavePanel = frame(gui, UDim2.fromOffset(360, 85), UDim2.new(0.5, 0, 0, 12))
wavePanel.AnchorPoint = Vector2.new(0.5, 0); stroke(wavePanel)
local waveLabel = text(wavePanel, "ESTABELECENDO CONTATO", 17, UDim2.fromOffset(15, 8), 24, colors.teal)
local waveDetail = text(wavePanel, "Carregando sobrevivente…", 12, UDim2.fromOffset(15, 38), 24, colors.sub)
local timeLabel = text(wavePanel, "", 24, UDim2.new(1, -78, 0, 11), 0, colors.gold)
timeLabel.Size, timeLabel.TextXAlignment = UDim2.fromOffset(64, 34), Enum.TextXAlignment.Right
local progress = frame(wavePanel, UDim2.new(1, -30, 0, 3), UDim2.new(0, 15, 1, -12), colors.line)
local progressFill = frame(progress, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), colors.teal)

local wallet = frame(gui, UDim2.fromOffset(198, 76), UDim2.new(1, -18, 0, 16))
wallet.AnchorPoint = Vector2.new(1, 0)
local coinsLabel = text(wallet, "◈ 0", 22, UDim2.fromOffset(12, 7), 20, colors.gold)
local recordLabel = text(wallet, "RECORDE 0   /   0 VITÓRIAS", 10, UDim2.fromOffset(12, 43), 20, colors.sub)

local survival = frame(gui, UDim2.fromOffset(250, 100), UDim2.new(0, 18, 1, -22))
survival.AnchorPoint = Vector2.new(0, 1)
local healthLabel = text(survival, "SOBREVIVENTE", 12, UDim2.fromOffset(12, 7), 24, colors.sub)
local hpBar = frame(survival, UDim2.new(1, -24, 0, 9), UDim2.fromOffset(12, 34), colors.line)
local hpFill = frame(hpBar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), colors.teal)
local staminaBar = frame(survival, UDim2.new(1, -24, 0, 3), UDim2.fromOffset(12, 51), colors.line)
local staminaFill = frame(staminaBar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), colors.gold)
local buffsLabel = text(survival, "SEM BUFFS • BUSQUE A ENERGIA", 10, UDim2.fromOffset(12, 66), 24, colors.sub)

local gunPanel = frame(gui, UDim2.fromOffset(240, 100), UDim2.new(1, -18, 1, -22))
gunPanel.AnchorPoint = Vector2.new(1, 1)
local gunName = text(gunPanel, "EQUIPE SUA ARMA", 12, UDim2.fromOffset(14, 6), 24, colors.sub)
local ammoLabel = text(gunPanel, "— / —", 30, UDim2.fromOffset(14, 27), 24)
local reloadLabel = text(gunPanel, if touch then "TOQUE PARA RECARREGAR" else "R / X RECARREGAR  •  1–4 ARMAS", 10, UDim2.fromOffset(14, 74), 24, colors.teal)

local objective = text(gui, "", 13, UDim2.new(0.5, 0, 1, -49), 0, colors.teal)
objective.Size, objective.AnchorPoint, objective.TextXAlignment = UDim2.fromOffset(400, 26), Vector2.new(0.5, 1), Enum.TextXAlignment.Center
local phaseHint = text(gui, "", 11, UDim2.new(0.5, 0, 1, -23), 0, colors.sub)
phaseHint.Size, phaseHint.AnchorPoint, phaseHint.TextXAlignment = UDim2.fromOffset(400, 24), Vector2.new(0.5, 1), Enum.TextXAlignment.Center

local crosshair = Instance.new("Frame"); crosshair.Size, crosshair.BackgroundTransparency, crosshair.Parent = UDim2.fromOffset(24, 24), 1, gui
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
for _, rect in { { 10, 0, 2, 7 }, { 10, 17, 2, 7 }, { 0, 10, 7, 2 }, { 17, 10, 7, 2 } } do
	frame(crosshair, UDim2.fromOffset(rect[3], rect[4]), UDim2.fromOffset(rect[1], rect[2]), colors.text)
end
local hitmarker = text(crosshair, "×", 40, UDim2.fromOffset(-10, -17), 0, colors.gold)
hitmarker.Size, hitmarker.Visible = UDim2.fromOffset(44, 48), false
local killLabel = text(gui, "", 15, UDim2.new(0.5, 0, 0.62, 0), 0, colors.gold)
killLabel.Size, killLabel.AnchorPoint, killLabel.TextXAlignment = UDim2.fromOffset(370, 30), Vector2.new(0.5, 0), Enum.TextXAlignment.Center

local toastHolder = frame(gui, UDim2.fromOffset(430, 54), UDim2.new(0.5, 0, 0, 156), colors.bg)
toastHolder.ZIndex = 40
toastHolder.AnchorPoint, toastHolder.Visible = Vector2.new(0.5, 0), false
local toastText = text(toastHolder, "", 13, UDim2.fromOffset(14, 4), 28)
toastText.Size, toastText.TextWrapped = UDim2.new(1, -28, 1, -8), true
local toastSerial = 0
local function toast(message, good)
	toastSerial += 1
	local serial = toastSerial
	toastText.Text, toastText.TextColor3, toastHolder.Visible = message, if good then colors.teal else colors.gold, true
	task.delay(4, function() if toastSerial == serial then toastHolder.Visible = false end end)
end

local banner = text(gui, "", 16, UDim2.new(0.5, 0, 0, 110), 0, colors.gold)
banner.Size, banner.AnchorPoint, banner.TextWrapped, banner.TextXAlignment = UDim2.fromOffset(660, 43), Vector2.new(0.5, 0), true, Enum.TextXAlignment.Center
local bannerSerial = 0
local function announce(message)
	bannerSerial += 1
	local serial = bannerSerial
	banner.Text = message
	task.delay(7, function() if serial == bannerSerial then banner.Text = "" end end)
end

-- Shop is an explicit player action. No purchase dialogs on death, login or countdowns.
local shade = frame(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0))
shade.ZIndex = 20
shade.BackgroundTransparency, shade.Visible, shade.Active = 0.25, false, true
local modal = frame(shade, UDim2.fromOffset(780, 530), UDim2.fromScale(0.5, 0.5), colors.bg)
modal.AnchorPoint = Vector2.new(0.5, 0.5); stroke(modal, colors.teal)
local modalScale = Instance.new("UIScale", modal)
local modalTitle = text(modal, "ARSENAL DO SOBREVIVENTE", 23, UDim2.fromOffset(24, 17), 90)
local modalSub = text(modal, "Acabamentos permanentes • equipe em qualquer arma", 12, UDim2.fromOffset(24, 53), 48, colors.sub)
button(modal, "FECHAR  ×", UDim2.fromOffset(100, 32), UDim2.new(1, -122, 0, 20), function() shade.Visible = false end)
local tabs = frame(modal, UDim2.new(1, -48, 0, 42), UDim2.fromOffset(24, 88), colors.panel)
local scroll = Instance.new("ScrollingFrame")
scroll.Size, scroll.Position, scroll.BackgroundTransparency = UDim2.new(1, -48, 1, -153), UDim2.fromOffset(24, 142), 1
scroll.BorderSizePixel, scroll.ScrollBarThickness, scroll.AutomaticCanvasSize, scroll.CanvasSize = 0, 4, Enum.AutomaticSize.Y, UDim2.fromOffset(0, 0)
scroll.Parent = modal
local listLayout = Instance.new("UIListLayout"); listLayout.Padding, listLayout.Parent = UDim.new(0, 10), scroll
local catalog, currentTab = {}, "Cosmetics"
local marker, markerPos
local firing, semiautoFired, nextShot = false, false, 0
local renderMenu

local function clearList()
	for _, child in scroll:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	scroll.CanvasPosition = Vector2.zero
end

local function card(title, detail, caption, callback, enabled, accent)
	local c = frame(scroll, UDim2.new(1, -8, 0, 90), UDim2.fromOffset(0, 0))
	local heading = text(c, title, 17, UDim2.fromOffset(16, 10), 240, accent or colors.text)
	local body = text(c, detail, 12, UDim2.fromOffset(16, 37), 235, colors.sub)
	body.Size, body.TextWrapped = UDim2.new(1, -240, 0, 42), true
	local buyButton = button(c, caption, UDim2.fromOffset(190, 42), UDim2.new(1, -207, 0, 24), if enabled then callback else nil, if enabled then colors.line else colors.panel)
	buyButton.AutoButtonColor, buyButton.TextColor3 = enabled, if enabled then colors.teal else colors.sub
	return heading
end

local function setWaypoint(position, name)
	if marker then marker:Destroy() end
	marker = Instance.new("Part")
	marker.Name, marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch, marker.Transparency = "ObjetivoLocal", true, false, false, false, 1
	marker.Size, marker.Position, marker.Parent = Vector3.one, position + Vector3.new(0, 14, 0), effects
	local bill = Instance.new("BillboardGui"); bill.Size, bill.AlwaysOnTop, bill.Parent = UDim2.fromOffset(170, 55), true, marker
	local label = text(bill, "▼ " .. name, 14, UDim2.fromOffset(0, 0), 0, colors.teal)
	label.Size, label.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	markerPos = position
	shade.Visible = false
end

local destinations = {
	{ "IGREJA", "Titã • resgate por moedas • acesso 100", Vector3.new(-112, 1, -30) },
	{ "DELEGACIA", "AR Aurora • mãos rápidas • acesso 130", Vector3.new(110, 1, -28) },
	{ "CENTRAL DE ENERGIA", "Acesso 170 + gerador 180 • habilita buffs e aprimoramento", Vector3.new(0, 1, -183) },
	{ "OFICINA", "SMG • aprimoramento até nível 3", Vector3.new(-128, 1, 103) },
	{ "MERCADO", "Escopeta • buff Corredor", Vector3.new(130, 1, 105) },
	{ "HOSPITAL", "Posto médico • cura completa por 60 moedas", Vector3.new(128, 1, -165) },
	{ "CEMITÉRIO E CRIPTA", "Loot gratuito • munição na cripta por 45 moedas", Vector3.new(-170, 1, -177) },
	{ "AVIÃO / HELIPONTO", "Extração depois da horda 15. Fique na zona verde no final.", Vector3.new(0, 1, 132) },
}

renderMenu = function()
	clearList()
	if currentTab == "Cosmetics" then
		modalSub.Text = "Seus suprimentos: " .. (player:GetAttribute("Coins") or 0) .. " • cores permanentes, sem dano extra"
		for _, id in { "Default", "Ember", "Arctic", "Toxic", "Violet" } do
			local skin = Balance.Skins[id]
			local owned, selected = player:GetAttribute("Skin_" .. id), player:GetAttribute("Skin") == id
			card(skin.Name, "Acabamento para todas as suas armas. Comprado com moedas ganhas jogando.",
				if selected then "EQUIPADO" elseif owned then "EQUIPAR" else "◈ " .. skin.Price .. " • COMPRAR", function()
					net.Action:FireServer("Skin", id)
				end, not selected, Color3.fromRGB(table.unpack(skin.Color)))
		end
	elseif currentTab == "Robux" then
		modalSub.Text = "Compras opcionais • preços e confirmação fornecidos pelo Roblox"
		if #catalog == 0 then card("LOJA INDISPONÍVEL", "Jogue para ganhar moedas, armas e buffs. Tente novamente mais tarde.", "AGUARDE", nil, false) end
		for _, product in catalog do
			local ownsPass = product.Kind == "Pass" and player:GetAttribute("Vanguard")
			local enabled = product.Available and player:GetAttribute("DataPersistent") == true and not ownsPass
			local caption = if ownsPass then "ADQUIRIDO" elseif not product.Available then "EM BREVE" elseif not player:GetAttribute("DataPersistent") then "SESSÃO TEMPORÁRIA" else product.Price .. " ROBUX"
			card(product.Name, product.Description, caption, function()
				local ok = pcall(function()
					if product.Kind == "Pass" then MarketplaceService:PromptGamePassPurchase(player, product.Id)
					else MarketplaceService:PromptProductPurchase(player, product.Id) end
				end)
				if not ok then toast("Não foi possível abrir a compra. Nenhum benefício foi concedido.") end
			end, enabled, colors.gold)
		end
	elseif currentTab == "Map" then
		modalSub.Text = "Selecione um destino para marcar no mundo • o norte aponta para a central"
		for _, place in destinations do card(place[1], place[2], "MARCAR DESTINO", function() setWaypoint(place[3], place[1]) end, true) end
	else
		modalSub.Text = "Solo ou equipe de até 6 sobreviventes • 15 hordas + extração"
		for _, tip in {
			{ "01 / PREPARE-SE", "Você começa com pistola e 120 moedas. A caixa de resgate é gratuita uma vez por horda: 25% de chance para cada arma." },
			{ "02 / RESTAURE A ENERGIA", "Abra a central ao norte e ligue o gerador. Desbloqueie buffs, aprimore armas e use a armadilha na praça." },
			{ "03 / LUTE E EXPLORE", "Atire na cabeça para 1,7× de dano. Loot renova por horda. Aproxime-se e use E, botão Y no controle ou o prompt na tela." },
			{ "04 / SOBREVIVA EM EQUIPE", "Eliminados voltam na preparação seguinte. Compre 1 resgate por partida na igreja por 90 moedas. Se todos caírem, a equipe tem 8 segundos." },
			{ "05 / O ÚLTIMO VOO", "Chefes nas hordas 5, 10 e 15. Ao final, chegue ao heliponto antes do cronômetro zerar. Extraídos ganham 300 moedas e uma vitória." },
			{ "CONTROLES", "PC: mouse atira, R recarrega, Shift corre, 1–4 armas. Controle: RT atira, X recarrega, L3 corre, D-pad direita abre loja. Celular: botões na tela e mira no centro." },
		} do card(tip[1], tip[2], "SOBREVIVA", nil, false) end
	end
end

for i, tab in { { "Cosmetics", "ACABAMENTOS" }, { "Robux", "ROBUX" }, { "Map", "MAPA" }, { "Guide", "COMO JOGAR" } } do
	button(tabs, tab[2], UDim2.fromOffset(170, 32), UDim2.fromOffset((i - 1) * 181 + 5, 5), function() currentTab = tab[1]; renderMenu() end)
end

ContextActionService:BindAction("ZumbiMenu", function(_, inputState, input)
	if inputState == Enum.UserInputState.Begin then
		shade.Visible, firing = not shade.Visible, false
		currentTab = if input.KeyCode == Enum.KeyCode.DPadUp then "Map" else "Cosmetics"
		renderMenu()
		GuiService.SelectedObject = if shade.Visible then tabs:FindFirstChildOfClass("TextButton") else nil
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadUp)

local menuButtons = frame(gui, UDim2.fromOffset(118, 137), UDim2.new(1, -18, 0.5, -75))
menuButtons.AnchorPoint = Vector2.new(1, 0)
button(menuButtons, "LOJA  /  B", UDim2.fromOffset(102, 34), UDim2.fromOffset(8, 8), function()
	shade.Visible, currentTab, firing = not shade.Visible, "Cosmetics", false; renderMenu()
end)
button(menuButtons, "MAPA  /  M", UDim2.fromOffset(102, 34), UDim2.fromOffset(8, 51), function()
	shade.Visible, currentTab, firing = true, "Map", false; renderMenu()
end)
button(menuButtons, "CONVIDAR", UDim2.fromOffset(102, 34), UDim2.fromOffset(8, 94), function()
	local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(player) end)
	if ok and can then pcall(function() SocialService:PromptGameInvite(player) end)
	else toast("Convites ficam disponíveis na experiência publicada.") end
end)

local deathPanel = frame(gui, UDim2.fromOffset(390, 116), UDim2.new(0.5, 0, 0.75, 0))
deathPanel.AnchorPoint, deathPanel.Visible = Vector2.new(0.5, 0.5), false
text(deathPanel, "ELIMINADO • VOLTE NA PRÓXIMA PAUSA", 12, UDim2.fromOffset(12, 8), 24, colors.red)
local rescueButton = button(deathPanel, "RESGATAR", UDim2.fromOffset(175, 36), UDim2.fromOffset(12, 43), function() net.Action:FireServer("Revive") end)
local spectateIndex = 0
button(deathPanel, "ESPECTAR →", UDim2.fromOffset(175, 36), UDim2.fromOffset(202, 43), function() spectateIndex += 1 end)
local rescueCount = text(deathPanel, "", 10, UDim2.fromOffset(12, 87), 24, colors.sub)

local radar = frame(gui, UDim2.fromOffset(160, 160), UDim2.fromOffset(18, 104), colors.bg)
stroke(radar)
text(radar, "N  /  CENTRAL", 9, UDim2.fromOffset(42, 3), 0, colors.teal).Size = UDim2.fromOffset(115, 20)
local function radarPosition(pos) return UDim2.fromScale(0.5 + pos.X / 560, 0.5 + pos.Z / 560) end
for _, place in destinations do
	local dot = frame(radar, UDim2.fromOffset(9, 9), radarPosition(place[3]), colors.line)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
end
local selfDot = frame(radar, UDim2.fromOffset(7, 7), UDim2.fromScale(0.5, 0.5), colors.teal)
selfDot.AnchorPoint = Vector2.new(0.5, 0.5)
local teamDots = {}

local currentHum, healthConnection, deathConnection
local function characterAdded(character)
	firing = false
	if healthConnection then healthConnection:Disconnect() end
	if deathConnection then deathConnection:Disconnect() end
	currentHum = character:WaitForChild("Humanoid", 10)
	if not currentHum then return end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	workspace.CurrentCamera.CameraSubject = currentHum
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 18
	local function updateHealth()
		local ratio = math.clamp(currentHum.Health / currentHum.MaxHealth, 0, 1)
		hpFill.Size = UDim2.fromScale(ratio, 1)
		hpFill.BackgroundColor3 = if ratio < 0.3 then colors.red else colors.teal
		healthLabel.Text = "VIDA " .. math.ceil(currentHum.Health) .. " / " .. math.ceil(currentHum.MaxHealth)
	end
	healthConnection = currentHum.HealthChanged:Connect(updateHealth)
	deathConnection = currentHum.Died:Connect(function() firing = false end)
	updateHealth()
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then task.spawn(characterAdded, player.Character) end

local function currentTool()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("WeaponId") and tool
end

local function aimPoint()
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray
	if touch or UserInputService:GetLastInputType().Name:find("Gamepad") then
		ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	else ray = camera:ScreenPointToRay(mouse.X, mouse.Y) end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character or effects, effects }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 500
end

local function doFire()
	if shade.Visible or not player:GetAttribute("InRound") or not currentHum or currentHum.Health <= 0 then return end
	local tool = currentTool()
	local def = tool and Balance.Weapons[tool:GetAttribute("WeaponId")]
	if not def or os.clock() < nextShot or (semiautoFired and not def.Automatic) then return end
	if tool:GetAttribute("Reloading") then return end
	if (tool:GetAttribute("Ammo") or 0) <= 0 then net.Reload:FireServer(); nextShot = os.clock() + 0.3; return end
	nextShot, semiautoFired = os.clock() + def.Interval, true
	net.Fire:FireServer(aimPoint())
end

local function fireInput(_, inputState)
	if shade.Visible or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if not currentTool() then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then firing, semiautoFired = true, false; doFire()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then firing = false end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("ZumbiShoot", fireInput, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("ZumbiReload", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and not shade.Visible and currentTool() then net.Reload:FireServer(); return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
local sprintHeld = false
ContextActionService:BindAction("ZumbiSprint", function(_, inputState, input)
	if inputState == Enum.UserInputState.Begin then
		if input.KeyCode == Enum.KeyCode.ButtonL3 then sprintHeld = not sprintHeld else sprintHeld = true end
	elseif inputState == Enum.UserInputState.End and input.KeyCode ~= Enum.KeyCode.ButtonL3 then sprintHeld = false end
	net.Action:FireServer("Sprint", sprintHeld)
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then shade.Visible, currentTab, firing = not shade.Visible, "Cosmetics", false; renderMenu()
	elseif input.KeyCode == Enum.KeyCode.M then shade.Visible, currentTab, firing = not shade.Visible, "Map", false; renderMenu()
	elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then shade.Visible = false end
end)
UserInputService.WindowFocusReleased:Connect(function()
	firing, sprintHeld = false, false
	net.Action:FireServer("Sprint", false)
end)

local touchButtons = frame(gui, UDim2.fromOffset(160, 140), UDim2.new(1, -30, 1, -190))
touchButtons.AnchorPoint, touchButtons.BackgroundTransparency, touchButtons.Visible = Vector2.new(1, 1), 1, touch
local shootButton = button(touchButtons, "ATIRAR", UDim2.fromOffset(74, 74), UDim2.fromOffset(80, 12), nil, colors.line)
rounded(shootButton, 37)
shootButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then firing, semiautoFired = true, false; doFire() end
end)
shootButton.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then firing = false end end)
button(touchButtons, "RECARGA", UDim2.fromOffset(72, 42), UDim2.fromOffset(1, 43), function() net.Reload:FireServer() end)
button(touchButtons, "CORRER", UDim2.fromOffset(108, 36), UDim2.fromOffset(43, 95), function()
	sprintHeld = not player:GetAttribute("Sprinting"); net.Action:FireServer("Sprint", sprintHeld)
end)

local function updateProfile()
	coinsLabel.Text = "◈ " .. (player:GetAttribute("Coins") or 0)
	recordLabel.Text = "RECORDE " .. (player:GetAttribute("BestWave") or 0) .. "   /   " .. (player:GetAttribute("Wins") or 0) .. " VITÓRIAS"
	staminaFill.Size = UDim2.fromScale((player:GetAttribute("Stamina") or 100) / 100, 1)
	local buffs = {}
	for _, key in { "Juggernaut", "QuickHands", "Runner" } do if player:GetAttribute(key) then table.insert(buffs, Balance.Perks[key].Name) end end
	if player:GetAttribute("Vanguard") then table.insert(buffs, "Vanguarda") end
	if (player:GetAttribute("BoostUntil") or 0) > os.time() then table.insert(buffs, "2× moedas") end
	buffsLabel.Text = if #buffs > 0 then table.concat(buffs, " • ") else "SEM BUFFS • BUSQUE A ENERGIA"
	deathPanel.Visible = player:GetAttribute("Eliminated") == true and (state:GetAttribute("Phase") == "Wave" or state:GetAttribute("Phase") == "Extraction")
	local revives = (player:GetAttribute("Revives") or 0) + (player:GetAttribute("RoundRevives") or 0)
	rescueButton.Text = "RESGATAR • " .. revives
	rescueCount.Text = "Resgates de partida: " .. (player:GetAttribute("RoundRevives") or 0) .. "  /  permanentes: " .. (player:GetAttribute("Revives") or 0)
end
player.AttributeChanged:Connect(function(key)
	updateProfile()
	if shade.Visible and (key == "Coins" or key == "Skin" or key == "DataPersistent" or key == "Vanguard") then renderMenu() end
end)
state.AttributeChanged:Connect(updateProfile)

net.Effects.OnClientEvent:Connect(function(kind, payload)
	if kind == "Toast" then toast(payload.Text, payload.Good)
	elseif kind == "Announcement" then announce(payload.Text)
	elseif kind == "Catalog" then catalog = payload; if shade.Visible and currentTab == "Robux" then renderMenu() end
	elseif kind == "Hit" then
		hitmarker.Visible, hitmarker.TextColor3 = true, if payload.Head then colors.gold else colors.teal
		local stamp = os.clock(); hitmarker:SetAttribute("Stamp", stamp)
		task.delay(0.12, function() if hitmarker:GetAttribute("Stamp") == stamp then hitmarker.Visible = false end end)
	elseif kind == "Kill" then
		killLabel.Text = (if payload.Boss then "COMANDANTE ABATIDO" else "INFECTADO ABATIDO") .. "  +" .. payload.Coins .. " ◈"
		local stamp = os.clock(); killLabel:SetAttribute("Stamp", stamp)
		task.delay(1.5, function() if killLabel:GetAttribute("Stamp") == stamp then killLabel.Text = "" end end)
	elseif kind == "Shot" then
		local camera = workspace.CurrentCamera
		if (camera.CFrame.Position - payload.Origin).Magnitude > 220 then return end
		for _, finish in payload.Ends do
			local length = (finish - payload.Origin).Magnitude
			if length > 0.1 then
				local tracer = Instance.new("Part"); tracer.Name, tracer.Anchored, tracer.CanCollide, tracer.CanQuery, tracer.CanTouch = "Tracer", true, false, false, false
				tracer.Size, tracer.CFrame = Vector3.new(0.055, 0.055, length), CFrame.lookAt(payload.Origin:Lerp(finish, 0.5), finish)
				tracer.Material, tracer.Color, tracer.Parent = Enum.Material.Neon, colors.gold, effects
				Debris:AddItem(tracer, 0.065)
			end
		end
		if payload.UserId == player.UserId then
			local tool = currentTool()
			local handle = tool and tool:FindFirstChild("Handle")
			if handle then
				local flash = Instance.new("PointLight"); flash.Color, flash.Brightness, flash.Range, flash.Parent = colors.gold, 2, 8, handle
				Debris:AddItem(flash, 0.06)
			end
		end
	elseif kind == "Waypoint" then setWaypoint(payload.Position, "EXTRAÇÃO")
	elseif kind == "Trap" then
		local ring = Instance.new("Part"); ring.Name, ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = "Descarga", true, false, false, false
		ring.Shape, ring.Size, ring.CFrame = Enum.PartType.Cylinder, Vector3.new(0.2, 50, 50), CFrame.new(payload.Position) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Material, ring.Color, ring.Transparency, ring.Parent = Enum.Material.Neon, colors.teal, 0.8, effects
		Debris:AddItem(ring, payload.Duration)
	end
end)

local phaseNames = { Waiting = "AGUARDANDO EQUIPE", Preparation = "PREPARAÇÃO", Wave = "HORDA", Extraction = "EXTRAÇÃO", Victory = "RESGATE CONCLUÍDO", GameOver = "A CIDADE CAIU" }
local renderAccumulator = 0
local lastRound = -1
RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local compact = viewport.X < 1000 or viewport.Y < 600
	modalScale.Scale = math.min(1, (viewport.X - 22) / 780, (viewport.Y - 32) / 530)
	brand.Visible, subtitle.Visible, radar.Visible = not compact, not compact, not compact
	local hudScale = if compact then math.clamp(viewport.X / 1000, 0.62, 0.85) else 1
	for _, panel in { wavePanel, wallet, survival, gunPanel, menuButtons, deathPanel, toastHolder } do
		local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", panel)
		scale.Scale = hudScale
	end
	banner.Size = UDim2.fromOffset(math.min(660, viewport.X - 32), 43)
	banner.TextSize = if compact then 12 else 16
	objective.Visible, phaseHint.Visible = not compact, not compact
	wavePanel.Position = if compact then UDim2.new(0, 12, 0, 8) else UDim2.new(0.5, 0, 0, 12)
	wavePanel.AnchorPoint = if compact then Vector2.zero else Vector2.new(0.5, 0)
	local mouse = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	local centered = touch or UserInputService:GetLastInputType().Name:find("Gamepad")
	crosshair.Position = if centered then UDim2.fromOffset(viewport.X / 2, viewport.Y / 2 - inset.Y) else UDim2.fromOffset(mouse.X - inset.X, mouse.Y - inset.Y)
	crosshair.Visible = currentTool() ~= nil and player:GetAttribute("InRound") == true and not shade.Visible
	if firing then doFire() end
	local targetFov = if player:GetAttribute("Sprinting") then 78 else 70
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 7, 1)
	renderAccumulator += dt
	if renderAccumulator < 0.1 then return end
	renderAccumulator = 0
	local round = state:GetAttribute("Round") or 0
	if round ~= lastRound then
		lastRound = round
		if marker then marker:Destroy(); marker = nil; markerPos = nil end
	end
	local phase = state:GetAttribute("Phase") or "Waiting"
	local wave = state:GetAttribute("Wave") or 0
	local seconds = math.max(0, math.ceil((state:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()))
	local wipe = state:GetAttribute("WipeAt") or 0
	waveLabel.Text = (phaseNames[phase] or phase) .. (if phase == "Wave" then "  " .. wave .. "/15" else "")
	waveDetail.Text = if phase == "Wave" then ((state:GetAttribute("Enemies") or 0) + (state:GetAttribute("Remaining") or 0)) .. " infectados • " .. (state:GetAttribute("Living") or 0) .. " sobreviventes" elseif phase == "Preparation" then "Explore • encontre loot • compre melhorias" elseif phase == "Extraction" then "Fique dentro da zona verde quando zerar" elseif phase == "Waiting" then "Carregando dados dos sobreviventes…" else "Recorde " .. (player:GetAttribute("BestWave") or 0) .. " • próxima tentativa em breve"
	timeLabel.Text = if wipe > 0 then "! " .. math.max(0, math.ceil(wipe - workspace:GetServerTimeNow())) elseif phase == "Wave" or phase == "Waiting" then "" else tostring(seconds) .. "s"
	progressFill.Size = UDim2.fromScale(math.clamp(wave / 15, 0.03, 1), 1)
	phaseHint.Text = if state:GetAttribute("Power") then "ENERGIA ATIVA  •  BUFFS DISPONÍVEIS" else "OBJETIVO: LIGAR A CENTRAL DE ENERGIA"
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		selfDot.Position = radarPosition(root.Position)
		if markerPos then objective.Text = "▼ DESTINO  •  " .. math.floor((root.Position - markerPos).Magnitude) .. " m"
		else objective.Text = "ABATES " .. (player:GetAttribute("RoundKills") or 0) .. "  /  " .. (if phase == "Extraction" then "ALCANCE O HELIPONTO" else "SOBREVIVA ÀS 15 HORDAS") end
	end
	local team = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("InRound") and other.Character then
			local r = other.Character:FindFirstChild("HumanoidRootPart")
			if r then
				table.insert(team, other)
				local dot = teamDots[other] or frame(radar, UDim2.fromOffset(5, 5), radarPosition(r.Position), colors.gold)
				dot.Position, dot.AnchorPoint = radarPosition(r.Position), Vector2.new(0.5, 0.5)
				teamDots[other] = dot
			end
		end
	end
	for other, dot in teamDots do if not table.find(team, other) then dot:Destroy(); teamDots[other] = nil end end
	if deathPanel.Visible and #team > 0 then
		local target = team[spectateIndex % #team + 1]
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
	local tool = currentTool()
	if tool then
		gunName.Text = string.upper(tool.Name)
		ammoLabel.Text = (tool:GetAttribute("Ammo") or 0) .. " / " .. (tool:GetAttribute("Reserve") or 0)
		ammoLabel.TextColor3 = if (tool:GetAttribute("Ammo") or 0) <= 3 then colors.gold else colors.text
		reloadLabel.Text = if tool:GetAttribute("Reloading") then "RECARREGANDO…" elseif touch then "TOQUE EM RECARGA" else "R / X RECARREGAR  •  1–4 ARMAS"
	else gunName.Text, ammoLabel.Text = "EQUIPE SUA ARMA", "— / —" end
end)

net.Action:FireServer("Ready")
updateProfile()
task.delay(5, function()
	if not player:GetAttribute("BestWave") or player:GetAttribute("BestWave") == 0 then
		currentTab = "Guide"; shade.Visible = true; firing = false; renderMenu()
	end
	if player:GetAttribute("DataReady") and not player:GetAttribute("DataPersistent") then toast("Sessão de teste: progresso temporário, compras indisponíveis.") end
end)
