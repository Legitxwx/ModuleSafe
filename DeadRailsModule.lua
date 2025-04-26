local DeadRailsModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Cam = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local rs = game:GetService("ReplicatedStorage")
local plr = LocalPlayer

-- Tạo các tab
local AimbotTab = Window:CreateTab("Aimbot", "Crosshair") -- Icon crosshair
local BringsTab = Window:CreateTab("Brings", "Package") -- Icon package
local ESPTab = Window:CreateTab("ESP", "Eye") -- Icon eye
local MovementTab = Window:CreateTab("Movement", "User") -- Icon user

-- Aimbot Variables
local validNPCs = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 1
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Transparency = 1
fovCircle.Filled = false
local fovRadius = 100
local aimbotEnabled = false
local aimbotKey = Enum.UserInputType.MouseButton2

-- ESP Variables
local ESPHandles = {}
local ESPEnabled = false
local ESPPlayerEnabled = false
local ESPZombyEnabled = false
local ESPColor = Color3.fromRGB(255, 0, 0)

-- Movement Variables
local speedHackEnabled = false
local speedValue = 16
local jumpHackEnabled = false
local jumpMultiplier = 1.5
local noClipEnabled = false
local infiniteJumpEnabled = false
local flyEnabled = false

-- Kill Aura Variables (Mới)
local auraOn = false
local killDist = 15

-- Helper Functions
local function updateFOV()
    fovCircle.Radius = fovRadius
    fovCircle.Position = Cam.ViewportSize / 2
end

local function isNPC(obj)
    return obj:IsA("Model") 
        and obj:FindFirstChild("Humanoid")
        and obj.Humanoid.Health > 0
        and obj:FindFirstChild("Head")
        and obj:FindFirstChild("HumanoidRootPart")
        and not Players:GetPlayerFromCharacter(obj)
end

local function updateNPCs()
    local tempTable = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isNPC(obj) then
            tempTable[obj] = true
        end
    end
    for i = #validNPCs, 1, -1 do
        if not tempTable[validNPCs[i]] then
            table.remove(validNPCs, i)
        end
    end
    for obj in pairs(tempTable) do
        if not table.find(validNPCs, obj) then
            table.insert(validNPCs, obj)
        end
    end
end

workspace.DescendantAdded:Connect(function(descendant)
    if isNPC(descendant) then
        table.insert(validNPCs, descendant)
        local humanoid = descendant:WaitForChild("Humanoid")
        humanoid.Destroying:Connect(function()
            for i = #validNPCs, 1, -1 do
                if validNPCs[i] == descendant then
                    table.remove(validNPCs, i)
                    break
                end
            end
        end)
    end
end)

workspace.DescendantRemoving:Connect(function(descendant)
    if isNPC(descendant) then
        for i =

 #validNPCs, 1, -1 do
            if validNPCs[i] == descendant then
                table.remove(validNPCs, i)
                break
            end
        end
    end
end)

local function predictPos(target)
    local rootPart = target:FindFirstChild("HumanoidRootPart")
    local head = target:FindFirstChild("Head")
    if not rootPart or not head then
        return head and head.Position or rootPart and rootPart.Position
    end
    local velocity = rootPart.Velocity
    local predictionTime = 0.02
    local basePosition = rootPart.Position + velocity * predictionTime
    local headOffset = head.Position - rootPart.Position
    return basePosition + headOffset
end

local function getTarget()
    local nearest = nil
    local minDistance = math.huge
    local viewportCenter = Cam.ViewportSize / 2
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    for _, npc in ipairs(validNPCs) do
        local predictedPos = predictPos(npc)
        local screenPos, visible = Cam:WorldToViewportPoint(predictedPos)
        if visible and screenPos.Z > 0 then
            local distance = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
            if distance <= fovRadius then
                local ray = workspace:Raycast(
                    Cam.CFrame.Position,
                    (predictedPos - Cam.CFrame.Position).Unit * 1000,
                    raycastParams
                )
                if ray and ray.Instance:IsDescendantOf(npc) then
                    if distance < minDistance then
                        minDistance = distance
                        nearest = npc
                    end
                end
            end
        end
    end
    return nearest
end

local function aim(targetPosition)
    local currentCF = Cam.CFrame
    local targetDirection = (targetPosition - currentCF.Position).Unit
    local smoothFactor = 0.581
    local newLookVector = currentCF.LookVector:Lerp(targetDirection, smoothFactor)
    Cam.CFrame = CFrame.new(currentCF.Position, currentCF.Position + newLookVector)
end

local function CreateESP(object, color)
    if not object or not object.PrimaryPart then return end
    if ESPHandles[object] then return end 

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = object
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.Parent = object

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.Adornee = object.PrimaryPart
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = object

    local textLabel = Instance.new("TextLabel")
    textLabel.Text = object.Name
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.TextColor3 = color
    textLabel.BackgroundTransparency = 1
    textLabel.TextSize = 7
    textLabel.Parent = billboard

    ESPHandles[object] = {Highlight = highlight, Billboard = billboard, Color = color}
end

local function ClearESP()
    for obj, handles in pairs(ESPHandles) do
        if handles.Highlight then handles.Highlight:Destroy() end
        if handles.Billboard then handles.Billboard:Destroy() end
        ESPHandles[obj] = nil
    end
end

local function UpdateESP()
    ClearESP()
    local runtimeItems = workspace:FindFirstChild("RuntimeItems")
    if runtimeItems then
        for _, item in ipairs(runtimeItems:GetDescendants()) do
            if item:IsA("Model") then
                CreateESP(item, Color3.new(1, 0, 0))
            end
        end
    end
    local nightEnemies = workspace:FindFirstChild("NightEnemies")
    if nightEnemies then
        for _, enemy in ipairs(nightEnemies:GetDescendants()) do
            if enemy:IsA("Model") then
                CreateESP(enemy, Color3.new(0, 0, 1))
            end
        end
    end
end

local function AddESPForPlayer(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or player == LocalPlayer then return end
    local character = player.Character
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    local espFrame = Instance.new("BillboardGui")
    espFrame.Parent = character
    espFrame.Adornee = humanoidRootPart
    espFrame.Size = UDim2.new(0, 100, 0, 40)
    espFrame.StudsOffset = Vector3.new(0, 3, 0)
    espFrame.AlwaysOnTop = true
    espFrame.Name = "ESPFrame"
    local frame = Instance.new("Frame")
    frame.Parent = espFrame
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    local healthText = Instance.new("TextLabel")
    healthText.Parent = frame
    healthText.Size = UDim2.new(1, 0, 0.3, 0)
    healthText.BackgroundTransparency = 1
    healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthText.TextSize = 10
    healthText.Text = "Health: " .. math.floor(humanoid.Health)
    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        healthText.Text = "Health: " .. math.floor(humanoid.Health)
    end)
end

local function AddESPForEnemy(enemy)
    if not enemy or not enemy:FindFirstChild("HumanoidRootPart") then return end
    local character = enemy
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    local espFrame = Instance.new("BillboardGui")
    espFrame.Parent = character
    espFrame.Adornee = humanoidRootPart
    espFrame.Size = UDim2.new(0, 100, 0, 40)
    espFrame.StudsOffset = Vector3.new(0, 3, 0)
    espFrame.AlwaysOnTop = true
    espFrame.Name = "ESPFrame"
    local frame = Instance.new("Frame")
    frame.Parent = espFrame
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    local healthText = Instance.new("TextLabel")
    healthText.Parent = frame
    healthText.Size = UDim2.new(1, 0, 0.3, 0)
    healthText.BackgroundTransparency = 1
    healthText.TextColor3 = ESPColor
    healthText.TextSize = 10
    healthText.Text = "Health: " .. math.floor(humanoid.Health)
    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        healthText.Text = "Health: " .. math.floor(humanoid.Health)
    end)
end

local function GetItemNames()
    local items = {}
    local runtimeItems = workspace:FindFirstChild("RuntimeItems")
    if runtimeItems then
        for _, item in ipairs(runtimeItems:GetDescendants()) do
            if item:IsA("Model") then
                table.insert(items, item.Name)
            end
        end
    end
    return items
end

local function applySpeedHack()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = speedHackEnabled and speedValue or 16
    end
end

local function applyJumpHack()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.JumpHeight = jumpHackEnabled and (7.2 * jumpMultiplier) or 7.2
    end
end

local function applyNoClip()
    if LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not noClipEnabled
            end
        end
    end
end

local function getNearestNPC()
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local nearest, minDist = nil, math.huge
    for _, npc in ipairs(workspace:GetDescendants()) do
        if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") and npc:FindFirstChild("Humanoid") and not game.Players:GetPlayerFromCharacter(npc) then
            local hrp, hum = npc.HumanoidRootPart, npc.Humanoid
            local dist = (hrp.Position - root.Position).Magnitude
            if hum.Health > 0 and dist < minDist and dist <= killDist then
                nearest, minDist = npc, dist
            end
        end
    end
    return nearest
end

local function dragAndKill(npc)
    if not npc then return end
    local hum = npc:FindFirstChild("Humanoid")
    if hum and hum.Health <= 0 then return end

    local dragRemote = rs:FindFirstChild("Shared") and rs.Shared:FindFirstChild("Remotes") and rs.Shared.Remotes:FindFirstChild("RequestStartDrag")
    if dragRemote then
        dragRemote:FireServer(npc)
        task.wait(0.5)
        if hum and hum.Health > 0 then npc:BreakJoints() end
    end
end

local function killAuraLoop()
    while auraOn do
        local target = getNearestNPC()
        if target then dragAndKill(target) end
        task.wait(0.2)
    end
end

-- Main Loop
local lastUpdate = 0
local UPDATE_INTERVAL = 0.4

RunService.Heartbeat:Connect(function(dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate >= UPDATE_INTERVAL then
        updateNPCs()
        lastUpdate = 0
    end
    if aimbotEnabled then
        local target = getTarget()
        if target then
            local predictedPosition = predictPos(target)
            aim(predictedPosition)
        end
    end
    if ESPPlayerEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and not player.Character:FindFirstChild("ESPFrame") then
                AddESPForPlayer(player)
            end
        end
    end
    if ESPZombyEnabled then
        for _, enemy in pairs(workspace:GetDescendants()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(enemy) and not enemy:FindFirstChild("ESPFrame") then
                AddESPForEnemy(enemy)
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    if noClipEnabled then
        applyNoClip()
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == aimbotKey then
        aimbotEnabled = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == aimbotKey then
        aimbotEnabled = false
    end
end)

return DeadRailsModule
