local ImGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/wiIlow/imgui-rbx/main/main.lua", true))()
local NotificationHolder = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Module.Lua"))()
local Notification = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Client.Lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local SPEED_THRESHOLD_SOFT = 60
local SPEED_THRESHOLD_HARD = 70
local CHEATER_COLOR = Color3.fromRGB(255, 0, 0) 

local AutoGreasword_Enabled = false
local AutoFrost_Enabled = false
local AutoShoot_Enabled = false
local ClickSelect_Kill_Enabled = false
local ClickSelect_Shoot_Enabled = false
local AntiFling_Enabled = false

-- VARIABLES SEPARADAS PARA OBJETIVOS
local TargetKillPlayerName = nil
local TargetShootPlayerName = nil

-- VARIABLES SEPARADAS PARA COMBATE
local AutoTPKill_Enabled = false 
local KillAura_Enabled = false 

local NotificationDuration = 3
local HoverTarget = nil
local CurrentHighlight = nil
local ClickSelect_Kill_CheckBox = nil
local ClickSelect_Shoot_CheckBox = nil

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local scriptName = "LocalScript"

local function disableAntiCheat(character)
    local antiCheat = character:WaitForChild(scriptName, 5)

    if antiCheat and antiCheat:IsA("LocalScript") then
        antiCheat.Disabled = true
        print("Anti-cheat '" .. scriptName .. "' deshabilitado en el personaje.")
    else
        warn("Advertencia: No se pudo encontrar/deshabilitar el anti-cheat '" .. scriptName .. "' en el personaje.")
    end
end

Player.CharacterAdded:Connect(disableAntiCheat)
if Player.Character then
    disableAntiCheat(Player.Character)
end

local CurrentWalkSpeed = 16
local CurrentJumpPower = 50

local ESP_SETTINGS = {
    Enabled = true,
    ShowInfo = false,
    BoxESP = false,
    EnemyColor = Color3.fromRGB(255, 80, 10), 
    MaxDistance = 500,
    BoxThickness = 1.5, 
    BoxFilled = false, 
    BoxTransparency = 0.7, 
}
local EspData = {}

local Typing = false
local _G_SendNotifications = true

local function ShowNotification(title, description, duration, outlineColor)
    local color = outlineColor or Color3.fromRGB(80, 80, 80)
    
    Notification:Notify(
        {Title = title, Description = description},
        {OutlineColor = color, Time = duration or NotificationDuration, Type = "default"}
    )
end

local function FindMyWeapon()
    local replicatedStorageWeapons = game:GetService("ReplicatedStorage"):FindFirstChild("Weapons")
    if not replicatedStorageWeapons then return nil end

    local localPlayerBackpack = LocalPlayer:FindFirstChild("Backpack")
    
    if localPlayerBackpack then
        for _, weaponTool in ipairs(replicatedStorageWeapons:GetChildren()) do
            if weaponTool:IsA("Tool") and localPlayerBackpack:FindFirstChild(weaponTool.Name) then
                return localPlayerBackpack:FindFirstChild(weaponTool.Name)
            end
        end
    end
    
    local localPlayerCharacter = LocalPlayer.Character
    if localPlayerCharacter then
        for _, weaponTool in ipairs(replicatedStorageWeapons:GetChildren()) do
            if weaponTool:IsA("Tool") and localPlayerCharacter:FindFirstChild(weaponTool.Name) then
                return localPlayerCharacter:FindFirstChild(weaponTool.Name)
            end
        end
    end
    
    return nil
end

local function GetDamageRemote(weaponTool)
    if weaponTool then
        return weaponTool:FindFirstChild("DamageRemote") or weaponTool:FindFirstChild("DamageRemote", true)
    end
    return nil
end

local function Greasword()
    local remote = nil
    for _, guiObject in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        remote = guiObject:FindFirstChild("RemoteEvent", true)
        if remote and remote:IsA("RemoteEvent") then
            break
        end
    end

    if remote then
        remote:FireServer("Emerald Greatsword")
    end
end

local function Frost()
    local remote = nil
    for _, guiObject in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        remote = guiObject:FindFirstChild("RemoteEvent", true)
        if remote and remote:IsA("RemoteEvent") then
            break
        end
    end

    if remote then
        remote:FireServer("Frost Spear")
    end
end

local function FindTargetHumanoid(searchString)
    if not searchString or searchString == "" then return nil end
    local searchLower = searchString:lower()
    local players = Players:GetChildren()
    for _, player in ipairs(players) do
        if player == LocalPlayer then continue end
        local nameLower = player.Name:lower()
        local displayNameLower = player.DisplayName:lower()
        if nameLower:find(searchLower, 1, true) or displayNameLower:find(searchLower, 1, true) then
            if player.Character then
                return player.Character:FindFirstChildOfClass("Humanoid")
            end
        end
    end
    return nil
end

local function FindClosestTarget()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not localRoot then return nil end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            
            if targetHumanoid and targetRoot and targetHumanoid.Health > 0 and targetRoot.CFrame.p.Magnitude > 0 then
                local distance = (localRoot.Position - targetRoot.Position).Magnitude
                
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer
end

local function PerformAttack(targetHumanoid)
    if not targetHumanoid or targetHumanoid.Health <= 0 then return end
    
    local weaponTool = FindMyWeapon()
    local damageRemote = GetDamageRemote(weaponTool)

    if damageRemote and damageRemote:IsA("RemoteEvent") then
        local args = {
            targetHumanoid
        }
        damageRemote:FireServer(unpack(args))
    end
end

local function ClearHoverHighlight()
    if CurrentHighlight and CurrentHighlight.Parent then
        CurrentHighlight.Parent = nil
        CurrentHighlight:Destroy()
        CurrentHighlight = nil
    end
end

local function ApplyHoverHighlight(character)
    if not CurrentHighlight then
        CurrentHighlight = Instance.new("Highlight")
        CurrentHighlight.FillColor = Color3.fromRGB(200, 200, 200)
        CurrentHighlight.FillTransparency = 0.6
        CurrentHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        CurrentHighlight.OutlineTransparency = 1.0
    end

    if CurrentHighlight.Parent ~= character then
        CurrentHighlight.Parent = character
    end
    CurrentHighlight.Enabled = true
end

local function MouseClickPlayer_Kill()
    if not ClickSelect_Kill_Enabled then return end
    local target = Mouse.Target
    if target then
        local targetModel = target:FindFirstAncestorOfClass("Model")
        if targetModel then
            local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
            if targetPlayer and targetPlayer ~= LocalPlayer then
                TargetKillPlayerName = targetPlayer.DisplayName
                ShowNotification("Objetivo Seleccionado (Auto Kill)", "Fijado en: " .. TargetKillPlayerName)

                if ClickSelect_Kill_CheckBox then
                    ClickSelect_Kill_CheckBox:Update(false)
                    ClickSelect_Kill_Enabled = false
                    ClearHoverHighlight()
                end
            end
        end
    end
end

local function MouseClickPlayer_Shoot()
    if not ClickSelect_Shoot_Enabled then return end
    local target = Mouse.Target
    if target then
        local targetModel = target:FindFirstAncestorOfClass("Model")
        if targetModel then
            local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
            if targetPlayer and targetPlayer ~= LocalPlayer then
                TargetShootPlayerName = targetPlayer.DisplayName
                ShowNotification("Objetivo Seleccionado (Auto Shoot)", "Fijado en: " .. TargetShootPlayerName, NotificationDuration, Color3.fromRGB(100, 150, 255)) -- Color diferente para distinguirlo

                if ClickSelect_Shoot_CheckBox then
                    ClickSelect_Shoot_CheckBox:Update(false)
                    ClickSelect_Shoot_Enabled = false
                    ClearHoverHighlight()
                end
            end
        end
    end
end

local function CreateSpeedTag(player, humanoidRootPart)
    local CHEATER_TAG_NAME = "CheaterTag"
    local billboard = humanoidRootPart:FindFirstChild(CHEATER_TAG_NAME)
    local hasWarned = false 

    local function removeTag()
        if billboard then
            billboard:Destroy()
            billboard = nil
        end
    end

    local function createTag(color)
        if billboard and billboard.Parent then
            billboard:Destroy()
        end
        billboard = Instance.new("BillboardGui")
        billboard.Name = CHEATER_TAG_NAME
        billboard.Size = UDim2.new(2, 0, 0.5, 0)
        billboard.AlwaysOnTop = true
        billboard.ExtentsOffset = Vector3.new(0, 3, 0)
        billboard.MaxDistance = 100
        local textLabel = Instance.new("TextLabel")
        textLabel.Text = "CHEATER"
        textLabel.TextScaled = true
        textLabel.TextColor3 = color
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextStrokeTransparency = 0.8
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Parent = billboard
        billboard.Parent = humanoidRootPart
    end

    local conn = RunService.Heartbeat:Connect(function()
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local rootPart = humanoidRootPart 

        if not humanoid or humanoid.Health <= 0 or not rootPart then
            removeTag()
            hasWarned = false
            return
        end

        local cheatType = nil
        local currentSpeed = humanoid.WalkSpeed
        
        if currentSpeed > SPEED_THRESHOLD_SOFT then
            cheatType = "Speed"
        end

        if not cheatType then
            local state = humanoid:GetState()
            
            if humanoid.PlatformStand then
                cheatType = "Fly (PlatformStand)"
            elseif not humanoid.FloorMaterial and rootPart.Position.Y > 5 and state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Climbing then
                cheatType = "Fly (Airborne)"
            end
        end

        if cheatType then
            local color = CHEATER_COLOR
            if not billboard or not billboard.Parent then
                createTag(color)
            else
                local textLabel = billboard:FindFirstChildOfClass("TextLabel")
                if textLabel and textLabel.TextColor3 ~= color then
                    textLabel.TextColor3 = color
                end
            end

            if not hasWarned then
                ShowNotification(
                    "¡CHEATER DETECTADO!", 
                    "Player '" .. player.Name .. "' está usando " .. cheatType .. " Hack!", 
                    5, 
                    CHEATER_COLOR
                )
                hasWarned = true
            end

        else
            removeTag()
            hasWarned = false
        end
    end)

    return { remove = removeTag, connection = conn }
end

local function CreateESP(player)
    if player == LocalPlayer then return end

    local espData = {
        connections = {},
        drawings = {
            text = Drawing.new("Text"),
            healthText = Drawing.new("Text"),
            box = Drawing.new("Square")
        },
        speedTagData = nil
    }

    for _, drawing in pairs(espData.drawings) do
        drawing.Visible = false
    end

    espData.drawings.text.Center = true
    espData.drawings.text.Outline = true
    espData.drawings.text.Font = 2
    espData.drawings.text.Size = 14

    espData.drawings.healthText.Center = true
    espData.drawings.healthText.Outline = true
    espData.drawings.healthText.Font = 2
    espData.drawings.healthText.Size = 14
    espData.drawings.healthText.Color = Color3.fromRGB(0, 255, 0)

    espData.drawings.box.Thickness = ESP_SETTINGS.BoxThickness
    espData.drawings.box.Filled = ESP_SETTINGS.BoxFilled

    EspData[player] = espData

    local function UpdateCharacter()
        for _, conn in ipairs(espData.connections) do
            conn:Disconnect()
        end
        espData.connections = {}

        if espData.speedTagData then
            espData.speedTagData.connection:Disconnect()
            espData.speedTagData.remove()
            espData.speedTagData = nil
        end

        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

        espData.speedTagData = CreateSpeedTag(player, humanoidRootPart)

        local function UpdateNametagVisibility()
            humanoid.DisplayDistanceType = (ESP_SETTINGS.ShowInfo or ESP_SETTINGS.BoxESP) and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
        end
        UpdateNametagVisibility()

        table.insert(espData.connections, player:GetPropertyChangedSignal("Team"):Connect(UpdateNametagVisibility))
        table.insert(espData.connections, player.CharacterAdded:Connect(UpdateNametagVisibility))

        local renderConn = RunService.RenderStepped:Connect(function()
            if not ESP_SETTINGS.Enabled or not character or not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
                espData.drawings.text.Visible = false
                espData.drawings.healthText.Visible = false
                espData.drawings.box.Visible = false
                return
            end

            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
            if distance > ESP_SETTINGS.MaxDistance then
                espData.drawings.text.Visible = false
                espData.drawings.healthText.Visible = false
                espData.drawings.box.Visible = false
                return
            end

            local HeadOffset = Vector3.new(0, 0.5, 0)
            local LegsOffset = Vector3.new(0, 3, 0)

            local Victim_HumanoidRootPart, OnScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
            local Victim_Head = Camera:WorldToViewportPoint(character:WaitForChild("Head").Position + HeadOffset)
            local Victim_Legs = Camera:WorldToViewportPoint(humanoidRootPart.Position - LegsOffset)

            local color = ESP_SETTINGS.EnemyColor

            if not OnScreen then
                espData.drawings.text.Visible = false
                espData.drawings.healthText.Visible = false
                espData.drawings.box.Visible = false
                return
            end

            local currentTextY = Victim_Head.Y - 20

            if ESP_SETTINGS.ShowInfo then
                espData.drawings.text.Text = player.DisplayName
                espData.drawings.text.Color = Color3.fromRGB(200, 200, 200)
                espData.drawings.text.Position = Vector2.new(Victim_Head.X, currentTextY)
                espData.drawings.text.Visible = true

                currentTextY = currentTextY + 15

                local healthValue = math.floor(humanoid.Health)
                espData.drawings.healthText.Text = tostring(healthValue) .. " HP"
                espData.drawings.healthText.Position = Vector2.new(Victim_Head.X, currentTextY)
                espData.drawings.healthText.Visible = true

            else
                espData.drawings.text.Visible = false
                espData.drawings.healthText.Visible = false
            end

            if ESP_SETTINGS.BoxESP then

                local boxHeight = Victim_Head.Y - Victim_Legs.Y
                local boxWidth = 2000 / Victim_HumanoidRootPart.Z

                if boxWidth < 5 then boxWidth = 5 end

                local boxLeftX = Victim_HumanoidRootPart.X - boxWidth / 2
                local boxTopY = Victim_HumanoidRootPart.Y - boxHeight / 2

                espData.drawings.box.Size = Vector2.new(boxWidth, boxHeight)
                espData.drawings.box.Position = Vector2.new(boxLeftX, boxTopY)
                espData.drawings.box.Color = color
                espData.drawings.box.Thickness = ESP_SETTINGS.BoxThickness
                espData.drawings.box.Transparency = ESP_SETTINGS.BoxTransparency
                espData.drawings.box.Filled = ESP_SETTINGS.BoxFilled

                espData.drawings.box.Visible = true
            else
                espData.drawings.box.Visible = false
            end
        end)
        table.insert(espData.connections, renderConn)

        table.insert(espData.connections, humanoid.Died:Connect(function()
            espData.drawings.text.Visible = false
            espData.drawings.healthText.Visible = false
            espData.drawings.box.Visible = false
        end))
    end

    player.CharacterAdded:Connect(UpdateCharacter)
    UpdateCharacter()
end

Players.PlayerRemoving:Connect(function(player)
    if EspData[player] then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        end

        if EspData[player].speedTagData then
            EspData[player].speedTagData.connection:Disconnect()
            EspData[player].speedTagData.remove()
        end

        for _, conn in ipairs(EspData[player].connections) do
            conn:Disconnect()
        end
        for _, drawing in pairs(EspData[player].drawings) do
            drawing:Remove()
        end
        EspData[player] = nil
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end
Players.PlayerAdded:Connect(CreateESP)


UserInputService.TextBoxFocused:Connect(function() Typing = true end)
UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)
UserInputService.InputBegan:Connect(function(input, isTyping)
    if not isTyping and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if ClickSelect_Kill_Enabled then
            MouseClickPlayer_Kill()
        elseif ClickSelect_Shoot_Enabled then
            MouseClickPlayer_Shoot()
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local isAnyClickSelectEnabled = ClickSelect_Kill_Enabled or ClickSelect_Shoot_Enabled

    if not isAnyClickSelectEnabled then
        if HoverTarget then ClearHoverHighlight() end
    else
        local currentTarget = nil
        local target = Mouse.Target
        if target then
            local targetModel = target:FindFirstAncestorOfClass("Model")
            if targetModel then
                local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
                if targetPlayer and targetPlayer ~= LocalPlayer and targetPlayer.Character then
                    currentTarget = targetPlayer
                end
            end
        end

        if currentTarget then
            ApplyHoverHighlight(currentTarget.Character)
            HoverTarget = currentTarget
        elseif HoverTarget then
            ClearHoverHighlight()
            HoverTarget = nil
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if LocalPlayer and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid.WalkSpeed ~= CurrentWalkSpeed then
                humanoid.WalkSpeed = CurrentWalkSpeed
            end
            if humanoid.JumpPower ~= CurrentJumpPower then
                humanoid.JumpPower = CurrentJumpPower
            end
        end
    end
end)



local Window = ImGui:Begin({
    Name = "Chaos KB [PRIVATE]",
    Width = 270,
    Height = 580
})

Window:Text("Start Features");

Window:CheckBox({
    Name = "Auto Emerald Greatsword",
    Enabled = AutoGreasword_Enabled,
    OnChanged = function(value)
        AutoGreasword_Enabled = value
    end
})

Window:CheckBox({
    Name = "Auto Frost Spear",
    Enabled = AutoFrost_Enabled,
    OnChanged = function(value)
        AutoFrost_Enabled = value
    end
})

Window:Text("Combat")





Window:InputText({
    Name = "Shoot Target",
    OnEnter = function(displayName)
        TargetShootPlayerName = displayName
        ShowNotification("Selected Player to Auto Shoot:" .. displayName)
    end
})

ClickSelect_Shoot_CheckBox = Window:CheckBox({
    Name = "Click Player to Target",
    Enabled = ClickSelect_Shoot_Enabled,
    OnChanged = function(value)
        ClickSelect_Shoot_Enabled = value
        ClickSelect_Kill_Enabled = false
        if ClickSelect_Kill_CheckBox then ClickSelect_Kill_CheckBox:Update(false) end
        if not value then
            ClearHoverHighlight()
        end
    end
})

Window:CheckBox({
    Name = "Auto Shoot",
    Enabled = AutoShoot_Enabled,
    OnChanged = function(value)
        AutoShoot_Enabled = value
    end
})

Window:InputText({
    Name = "Kill Target",
    OnEnter = function(displayName)
        TargetKillPlayerName = displayName
        ShowNotification("Selected Player to Auto Kill: " .. displayName)
    end
})


ClickSelect_Kill_CheckBox = Window:CheckBox({
    Name = "Click Player to Target",
    Enabled = ClickSelect_Kill_Enabled,
    OnChanged = function(value)
        ClickSelect_Kill_Enabled = value
        ClickSelect_Shoot_Enabled = false
        if ClickSelect_Shoot_CheckBox then ClickSelect_Shoot_CheckBox:Update(false) end 
        if not value then
            ClearHoverHighlight()
        end
    end
})

Window:CheckBox({
    Name = "Auto Kill",
    Enabled = AutoTPKill_Enabled,
    OnChanged = function(value)
        AutoTPKill_Enabled = value
        if value then
            ShowNotification("Auto Kill", "Activado. Requiere Target Kill fijado.")
        end
    end
})

Window:CheckBox({
    Name = "Kill Aura",
    Enabled = KillAura_Enabled,
    OnChanged = function(value)
        KillAura_Enabled = value
        if value then
            ShowNotification("Kill Aura", "Activado. Atacando al más cercano dentro del rango de arma.")
        end
    end
})


Window:Text("ESP")


Window:CheckBox({
    Name = "Nametags & Health",
    Enabled = ESP_SETTINGS.ShowInfo,
    OnChanged = function(value)
        ESP_SETTINGS.ShowInfo = value
    end
})

Window:CheckBox({
    Name = "Box",
    Enabled = ESP_SETTINGS.BoxESP,
    OnChanged = function(value)
        ESP_SETTINGS.BoxESP = value
    end
})


Window:Text("Movement")


Window:SliderFloat({
    Name = "WalkSpeed",
    Min = 16,
    Max = 100,
    Default = 16,
    OnChanged = function(value)
        CurrentWalkSpeed = value
    end
})


Window:SliderFloat({
    Name = "JumpPower",
    Min = 50,
    Max = 200,
    Default = 50,
    OnChanged = function(value)
        CurrentJumpPower = value
    end
})


Window:Button("Anti Fling"):Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/sytcal/antifling/main/9999"))()
end)


Window:End()

spawn(function()
    while task.wait(0.10) do
        if AutoGreasword_Enabled == true then
            Greasword()
            task.wait(0.05)
            local menuScreen = LocalPlayer.PlayerGui:FindFirstChild("Menu Screen")
            if menuScreen and menuScreen:IsA("ScreenGui") then
                menuScreen.Enabled = false
            end
        end
    end
end)


spawn(function()
    while task.wait(0.10) do
        if AutoFrost_Enabled == true then
            Frost()
            task.wait(0.05)
            local menuScreen = LocalPlayer.PlayerGui:FindFirstChild("Menu Screen")
            if menuScreen and menuScreen:IsA("ScreenGui") then
                menuScreen.Enabled = false
            end
        end
    end
end)

spawn(function()
    while task.wait(0.10) do
        if AutoGreasword_Enabled == true then
            Greasword()
            task.wait(0.05)

            local menuScreen = LocalPlayer.PlayerGui:FindFirstChild("Menu Screen")
            if menuScreen and menuScreen:IsA("ScreenGui") then
                menuScreen.Enabled = false
            end
        end
    end
end)


spawn(function()
    while task.wait(0.10) do
        if AutoFrost_Enabled == true then
            Frost()
            task.wait(0.05)

            local menuScreen = LocalPlayer.PlayerGui:FindFirstChild("Menu Screen")
            if menuScreen and menuScreen:IsA("ScreenGui") then
                menuScreen.Enabled = false
            end
        end
    end
end)

spawn(function()
    while task.wait(0.5) do
        if AutoShoot_Enabled and TargetShootPlayerName and LocalPlayer.Character then 
            local targetHumanoid = FindTargetHumanoid(TargetShootPlayerName) -- Usar la variable correcta aquí también
            local targetChar = targetHumanoid and targetHumanoid.Parent
            local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

            local revolver = LocalPlayer.Character:FindFirstChild("Kawaii Revolver")
            local damageRemote = revolver and (revolver:FindFirstChild("DamageRemote") or revolver:FindFirstChild("DamageRemote", true))

            if targetRoot and damageRemote and damageRemote:IsA("RemoteEvent") then
                local targetPosition = targetRoot.Position
                local args = {
                    targetHumanoid,
                    targetPosition
                }
                damageRemote:FireServer(unpack(args))
            end
        end
    end
end)


spawn(function()
    while task.wait(0.05) do 
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local localRoot = LocalPlayer.Character.HumanoidRootPart
            local targetHumanoid = nil

            if AutoTPKill_Enabled and TargetKillPlayerName and TargetKillPlayerName ~= "" then
                targetHumanoid = FindTargetHumanoid(TargetKillPlayerName)
                
                if targetHumanoid and targetHumanoid.Health > 0 and targetHumanoid.Parent:FindFirstChild("Head") then

                    local targetHead = targetHumanoid.Parent.Head
                    local offset = Vector3.new(0, 1, -2) 
                    local newCFrame = targetHead.CFrame * CFrame.new(offset)
                    
                    localRoot.CFrame = newCFrame

                    PerformAttack(targetHumanoid)
                    
                elseif targetHumanoid and targetHumanoid.Health <= 0 then
                    TargetKillPlayerName = nil
                

            elseif KillAura_Enabled then
                local closestPlayer = FindClosestTarget()
                if closestPlayer then
                    targetHumanoid = closestPlayer.Character and closestPlayer.Character:FindFirstChildOfClass("Humanoid")

                    if targetHumanoid and targetHumanoid.Health > 0 then
                        PerformAttack(targetHumanoid)
                    end
                end
            end
        end
    end
    end
end)
