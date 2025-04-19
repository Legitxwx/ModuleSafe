-- NebulaStrike | Full Player Protection Module (Auto)

if getgenv().NebulaStrikePlayerProtection then return end
getgenv().NebulaStrikePlayerProtection = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function protect()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if root then
        -- Anti-Fling
        if root.Velocity.Magnitude > 150 then
            root.Velocity = Vector3.zero
            root.RotVelocity = Vector3.zero
            warn("[NebulaStrike Protection] Fling blocked!")
        end

        -- Anti-Void
        if root.Position.Y < -30 then
            root.CFrame = CFrame.new(0, 10, 0) -- Safe TP
            warn("[NebulaStrike Protection] Void rescue activated!")
        end

        -- Anti-Freeze
        if root.Anchored then
            root.Anchored = false
            warn("[NebulaStrike Protection] Unfrozen!")
        end
    end

    -- Anti-Kill
    if hum and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
        warn("[NebulaStrike Protection] Health restored!")
    end
end

-- Hook protection into every frame
RunService.Heartbeat:Connect(protect)

-- Auto-apply on character spawn
LocalPlayer.CharacterAdded:Connect(function()
    wait(1)
    protect()
end)

warn("[NebulaStrike] Player Protection Module Loaded")
