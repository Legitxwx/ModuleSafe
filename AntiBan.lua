-- NebulaStrike | Full Auto Anti-Ban System

if getgenv().NebulaStrikeAntiBan then return end
getgenv().NebulaStrikeAntiBan = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local mt = getrawmetatable(game)
local protect_methods = {"Kick", "kick", "Teleport", "TeleportToPlaceInstance"}

setreadonly(mt, false)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index

-- Block namecalls like player:Kick(), TeleportService:Teleport(), etc
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if table.find(protect_methods, method) and self == LocalPlayer then
        warn("[NebulaStrike Anti-Ban] Blocked namecall:", method)
        return nil
    end

    if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
        local n = tostring(self.Name):lower()
        if n:find("ban") or n:find("kick") or n:find("tp") or n:find("teleport") then
            warn("[NebulaStrike Anti-Ban] Blocked suspicious remote:", self:GetFullName())
            return function() return nil end
        end
    end

    return oldNamecall(self, unpack(args))
end)

-- Block index-based kicks: Player.Kick
mt.__index = newcclosure(function(self, key)
    if self == LocalPlayer and (key == "Kick" or key == "kick") then
        warn("[NebulaStrike Anti-Ban] Blocked .Kick via index")
        return function() return nil end
    end
    return oldIndex(self, key)
end)

-- Block TeleportService functions
pcall(function()
    hookfunction(TeleportService.Teleport, function(...)
        warn("[NebulaStrike Anti-Ban] TeleportService:Teleport blocked")
        return nil
    end)

    hookfunction(TeleportService.TeleportToPlaceInstance, function(...)
        warn("[NebulaStrike Anti-Ban] TeleportToPlaceInstance blocked")
        return nil
    end)
end)

-- Protect Humanoid from health drops or being deleted
local function protectCharacter(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:GetPropertyChangedSignal("Health"):Connect(function()
            if hum.Health <= 0 then
                hum.Health = 100
                warn("[NebulaStrike Anti-Ban] Health loss blocked")
            end
        end)

        hum.AncestryChanged:Connect(function(_, parent)
            if not parent then
                warn("[NebulaStrike Anti-Ban] Humanoid removal blocked")
                local newHum = hum:Clone()
                newHum.Parent = char
            end
        end)
    end
end

-- Apply to current and future characters
if LocalPlayer.Character then
    protectCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(protectCharacter)

-- Destroy any new remotes that seem like kick/ban/teleport
game.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        local n = tostring(obj.Name):lower()
        if n:find("ban") or n:find("kick") or n:find("tp") or n:find("teleport") then
            warn("[NebulaStrike Anti-Ban] Destroyed suspicious remote:", obj:GetFullName())
            obj:Destroy()
        end
    end
end)

warn("[NebulaStrike] Full Anti-Ban Protection Enabled")
