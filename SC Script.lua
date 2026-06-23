if _G.ProjectEToHLoaded then
    warn("[Project EToH Script] Already loaded!")
    return
end

local autoExecuteFile = "ProjectEToHScript/auto_execute.txt"
local uiStyleFile = "ProjectEToHScript/ui_style.txt"
local autoExecuteDefault = false
pcall(function()
    if isfile(autoExecuteFile) then
        autoExecuteDefault = readfile(autoExecuteFile) == "true"
    end
end)
local uiStyle = "Obsidian"
pcall(function()
    if isfile(uiStyleFile) then
        uiStyle = readfile(uiStyleFile)
    end
end)

local repo
if uiStyle == "Linoria" then
    repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
else
    repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
end
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()

local function missing(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end

local okHook, errHook = pcall(function() hookmetamethod = missing("function", hookmetamethod) end)
local okNcm,  errNcm  = pcall(function() getnamecallmethod = missing("function", getnamecallmethod or get_namecall_method) end)
local queueteleport   = missing("function", queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport))

local sUNCSupport = {
    hookmetamethod    = okHook and hookmetamethod ~= nil,
    getnamecallmethod = okNcm  and getnamecallmethod ~= nil,
    queueteleport     = queueteleport ~= nil,
}
sUNCSupport.Godmode = sUNCSupport.hookmetamethod and sUNCSupport.getnamecallmethod

print("[Project EToH Script] Functions Check:")
print("[Project EToH Script] Metatable Library:")
print((sUNCSupport.hookmetamethod    and "✅" or "❌") .. " hookmetamethod"    .. (not okHook and ": " .. tostring(errHook) or ""))
print((sUNCSupport.getnamecallmethod and "✅" or "❌") .. " getnamecallmethod" .. (not okNcm  and ": " .. tostring(errNcm)  or ""))
print("[Project EToH Script] Miscellaneous Library:")
print((sUNCSupport.queueteleport     and "✅" or "❌") .. " queueonteleport")
local HttpService = game:GetService("HttpService")
local version = "Unknown"
local ok, result = pcall(function()
    local data = HttpService:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/cslp1/Project-SC-Script/refs/heads/main/version.json"))
    return data.version
end)
if ok and result then version = result end
local Window = Library:CreateWindow({
    Title         = "Project EToH Script",
    Footer        = "Game: Eternal Towers of Hell | Version " .. version,
    NotifySide    = "Right",
    ToggleKeybind = Enum.KeyCode.RightShift,
    AutoShow      = true,
})
local isDev = game:GetService("Players").LocalPlayer.Name == "MaybeIsRealZack"

local Tabs = {
    Main       = Window:AddTab("Main",        "zap"),
    UISettings = Window:AddTab("UI Settings", "settings"),
}
local Options  = Library.Options
local isAutoPlaying = false
local currentResolvedSteps = nil

-- === FANGAME CONFIG ===
-- To add a new fangame: add a new entry to gameConfigs with the folder name
-- and all Place IDs used by that game, then create the matching files in the repo.
local gameConfigs = {
    {
        folder   = "EToH",
        placeIds = { 9070657865, 9070979698 },
    },
    -- ADD NEW FANGAMES BELOW:
    {
        folder   = "st",
        placeIds = { 72577867400900, 129965911879791 },
    },
}

local selectedFolder = "EToH"  -- default fallback
for _, gc in ipairs(gameConfigs) do
    for _, pid in ipairs(gc.placeIds) do
        if game.PlaceId == pid then
            selectedFolder = gc.folder
            break
        end
    end
end

local baseRepo    = "https://raw.githubusercontent.com/cslp1/Project-SC-Script/refs/heads/main/Games/" .. selectedFolder .. "/"
local registryUrl = baseRepo .. "TowerRegistry.lua"
-- === END FANGAME CONFIG ===

local Registry
local ok_reg, reg_src = pcall(function() return game:HttpGet(registryUrl) end)
if ok_reg and reg_src then
    local fn = loadstring(reg_src)
    if fn then
        local ok2, result = pcall(fn)
        if ok2 then Registry = result end
    end
end
if not Registry then
    Registry = {
        Categories = { Ring1 = 9070657865, Ring2 = 9070979698 },
        Towers = {},
        TowerRush = {},
    }
end

local SuggestedTimes = {}
local TowerConfigs   = {}
local DropdownValues = {}

local function getTpFrameName(name)
    local colonPos = name:find(":")
    return colonPos and name:sub(1, colonPos - 1) or name
end

-- Studs from the HumanoidRootPart center to the character's feet.
local PLAYER_FOOT_OFFSET = 3
-- Returns a position on top of `part`'s surface, raised so the character stands
-- on top of it instead of clipping into the part. Accounts for the part's size
-- and orientation so it works for thick and rotated parts, not just thin ones.
local function getTopPos(part)
    local cf, size = part.CFrame, part.Size
    local halfTop = 0.5 * (
        math.abs(cf.UpVector.Y)    * size.Y +
        math.abs(cf.RightVector.Y) * size.X +
        math.abs(cf.LookVector.Y)  * size.Z
    )
    return part.Position + Vector3.new(0, halfTop + PLAYER_FOOT_OFFSET, 0)
end

local currentPlaceId = game.PlaceId

local function findNearestPortal(towerName)
    local tower = workspace.Towers[towerName]
    if not tower then return nil end
    local refPart = tower:FindFirstChildWhichIsA("BasePart", true)
    if not refPart then return nil end
    local refPos = refPart.Position
    local closest, closestDist = nil, math.huge
    if workspace:FindFirstChild("Portals") then
        for _, v in ipairs(workspace.Portals:GetChildren()) do
            if v:IsA("BasePart") then
                local dist = (v.Position - refPos).Magnitude
                if dist < closestDist then
                    closest = v
                    closestDist = dist
                end
            end
        end
    end
    return closest
end

for _, tower in ipairs(Registry.Towers) do
    local n = tower.name
    local placeId = Registry.Categories[tower.category]
    if placeId ~= currentPlaceId then continue end
    SuggestedTimes[n] = tower.suggestedTime
    local tpName = getTpFrameName(n)
    if selectedFolder == "st" then
        local portalIndex = tower.portalIndex
        TowerConfigs[n] = {
            tpFrame = function()
                if portalIndex then return workspace.Portals:GetChildren()[portalIndex] end
                return findNearestPortal(tpName)
            end,
            teleportTo = function()
                if portalIndex then return workspace.Portals:GetChildren()[portalIndex] end
                return findNearestPortal(tpName)
            end,
            routeUrl = baseRepo .. tower.category .. "/" .. n .. ".lua",
        }
    else
        TowerConfigs[n] = {
            tpFrame    = function() return workspace.Towers[tpName].Teleporter.Teleporter.TPFRAME end,
            teleportTo = function() return workspace.Towers[tpName].Teleporter.TeleportTo end,
            routeUrl   = baseRepo .. tower.category .. "/" .. n .. ".lua",
        }
    end
    table.insert(DropdownValues, n)
end

for _, tr in ipairs(Registry.TowerRush) do
    local n = tr.name
    local placeId = Registry.Categories[tr.category]
    if placeId ~= currentPlaceId then continue end
    SuggestedTimes[n] = tr.suggestedTime
    TowerConfigs[n] = {
        tpFrame = function()
            local tower = workspace.Towers[n]
            local ok1, tp1 = pcall(function() return tower.Teleporter.Teleporter.Teleport end)
            if ok1 and tp1 then return tp1 end
            local ok2, tp2 = pcall(function() return tower.Teleporter.Teleporter.TowerRushPortal.Teleport end)
            if ok2 and tp2 then return tp2 end
            return nil
        end,
        routeUrl    = baseRepo .. tr.category .. "/" .. n .. ".lua",
        isTowerRush = true,
    }
    table.insert(DropdownValues, n)
end

local TowerBox = Tabs.Main:AddLeftGroupbox("Towers")
local AllJumpBox = Tabs.Main:AddLeftGroupbox("All Jump Mode")
local function getSuggestedLabel(tower)
    tower = tower or "NEAT"
    local t = SuggestedTimes[tower]
    if t then
        return tower .. " Suggested Time: " .. t.min .. ":" .. (t.sec == "0" and "00" or t.sec)
    end
    return "No suggested time available"
end
local SuggestedLabel
TowerBox:AddDropdown("TowerSelect", {
    Text    = "Select Tower",
    Values  = DropdownValues,
    Default = DropdownValues[1] or "NEAT",
    Callback = function(value)
        if Library.Toggles.UseSuggestedTime.Value then
            local t = SuggestedTimes[value]
            if t then
                Library.Options.CompletionMin:SetValue(t.min)
                Library.Options.CompletionSec:SetValue(t.sec)
            end
        end
        SuggestedLabel:SetText(getSuggestedLabel(value))
        Library.Toggles.UseSuggestedTime:SetDisabled(false)
        Library.Options.CompletionMin:SetDisabled(not Library.Toggles.UseSuggestedTime.Value)
        Library.Options.CompletionSec:SetDisabled(not Library.Toggles.UseSuggestedTime.Value)
    end,
})
TowerBox:AddToggle("UseSuggestedTime", {
    Text    = "Use Suggested Time",
    Default = true,
    Callback = function(state)
        Library.Options.CompletionMin:SetDisabled(state)
        Library.Options.CompletionSec:SetDisabled(state)
        if state then
            local t = SuggestedTimes[Library.Options.TowerSelect.Value]
            if t then
                Library.Options.CompletionMin:SetValue(t.min)
                Library.Options.CompletionSec:SetValue(t.sec)
            end
        end
    end,
})
SuggestedLabel = TowerBox:AddLabel(getSuggestedLabel("NEAT"))
TowerBox:AddInput("CompletionMin", {
    Text        = "Completion Time (min)",
    Default     = "3",
    Numeric     = true,
    Placeholder = "3",
})
TowerBox:AddInput("CompletionSec", {
    Text        = "Completion Time (s)",
    Default     = "0",
    Numeric     = true,
    Placeholder = "0",
})
local routeHighlights = {}
local routeUpdateConn = nil

local function clearRouteHighlights()
    if routeUpdateConn then
        routeUpdateConn:Disconnect()
        routeUpdateConn = nil
    end
    for _, obj in ipairs(routeHighlights) do
        obj:Destroy()
    end
    routeHighlights = {}
end

local MAX_SIZE = 2048

local function buildSegmentParts(folder, a, b)
    local parts = {}
    local dir  = (b - a)
    local dist = dir.Magnitude
    if dist <= 0 then return parts end
    local segments = math.ceil(dist / MAX_SIZE)
    for s = 0, segments - 1 do
        local segStart = a + dir * (s / segments)
        local segEnd   = a + dir * ((s + 1) / segments)
        local segMid   = (segStart + segEnd) / 2
        local segDist  = (segEnd - segStart).Magnitude
        local part = Instance.new("Part")
        part.Anchored     = true
        part.CanCollide   = false
        part.CastShadow   = false
        part.Size         = Vector3.new(0.3, 0.3, segDist)
        part.CFrame       = CFrame.lookAt(segMid, segEnd)
        part.Material     = Enum.Material.Neon
        part.Color        = Options.RouteColor and Options.RouteColor.Value or Color3.fromRGB(0, 255, 0)
        part.Transparency = 0
        part.Parent       = folder
        table.insert(parts, part)
    end
    return parts
end

local function showRoute(resolvedSteps)
    clearRouteHighlights()
    if not resolvedSteps then return end

    local points = {}
    for _, step in ipairs(resolvedSteps) do
        if step.type ~= "jump" and step.destPos then
            table.insert(points, { pos = step.destPos, target = step.target })
        end
    end

    local folder = Instance.new("Folder")
    folder.Name   = "RouteHighlight"
    folder.Parent = workspace
    table.insert(routeHighlights, folder)

    local links = {}
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local posA = (a.target and a.target.Parent) and getTopPos(a.target) or a.pos
        local posB = (b.target and b.target.Parent) and getTopPos(b.target) or b.pos
        local link = { posA = posA, posB = posB, targetA = a.target, targetB = b.target, parts = {} }
        link.parts = buildSegmentParts(folder, link.posA, link.posB)
        for _, p in ipairs(link.parts) do table.insert(routeHighlights, p) end
        if link.targetA or link.targetB then
            table.insert(links, link)
        end
    end

    if #links > 0 then
        local RunService = game:GetService("RunService")
        local lastCheck  = 0
        routeUpdateConn = RunService.Heartbeat:Connect(function()
            if os.clock() - lastCheck < 0.1 then return end
            lastCheck = os.clock()
            for _, link in ipairs(links) do
                local a = link.posA
                local b = link.posB
                if link.targetA and link.targetA.Parent then
                    a = getTopPos(link.targetA)
                end
                if link.targetB and link.targetB.Parent then
                    b = getTopPos(link.targetB)
                end
                if (a - link.posA).Magnitude > 0.1 or (b - link.posB).Magnitude > 0.1 then
                    for _, p in ipairs(link.parts) do
                        p:Destroy()
                        for idx, h in ipairs(routeHighlights) do
                            if h == p then table.remove(routeHighlights, idx) break end
                        end
                    end
                    link.posA  = a
                    link.posB  = b
                    link.parts = buildSegmentParts(folder, a, b)
                    for _, p in ipairs(link.parts) do table.insert(routeHighlights, p) end
                end
            end
        end)
    end
end

local ShowRouteToggle = TowerBox:AddToggle("ShowRoute", {
    Text    = "Show Route",
    Default = false,
    Tooltip = "Show route with parts connecting each checkpoint",
    Callback = function(state)
        if state then
            if isAutoPlaying and currentResolvedSteps then
                showRoute(currentResolvedSteps)
                return
            end
            local selected = Library.Options.TowerSelect.Value
            local config   = TowerConfigs[selected]
            if not config then return end
            local routeSrc
            local ok = pcall(function() routeSrc = game:HttpGet(config.routeUrl) end)
            if not ok or not routeSrc then return end
            local fn = loadstring(routeSrc)
            if not fn then return end
            local ok2, getCheckpoints = pcall(fn)
            if not ok2 or type(getCheckpoints) ~= "function" then return end
            local ok3, checkpoints = pcall(getCheckpoints)
            if not ok3 or type(checkpoints) ~= "table" then return end
            local steps = {}
            local prevPos = game:GetService("Players").LocalPlayer.Character and
                game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and
                game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero
            for _, step in ipairs(checkpoints) do
                if step == "jump" then
                    table.insert(steps, { type = "jump" })
                    continue
                end
                local target = typeof(step) == "Instance" and step or (type(step) == "table" and step.target)
                if target and target:IsA("BasePart") then
                    local destPos = getTopPos(target)
                    table.insert(steps, { type = "tween", target = target, destPos = destPos, dist = (destPos - prevPos).Magnitude })
                    prevPos = destPos
                end
            end
            showRoute(steps)
        else
            clearRouteHighlights()
        end
    end,
})
ShowRouteToggle:AddColorPicker("RouteColor", {
    Default  = Color3.fromRGB(0, 255, 0),
    Title    = "Route Color",
    Callback = function(value)
        for _, obj in ipairs(routeHighlights) do
            if obj:IsA("Part") then
                obj.Color = value
            end
        end
    end,
})
TowerBox:AddToggle("AutoReturnToLobby", {
    Text    = "Return to Lobby",
    Default = false,
    Tooltip = "Automatically return to lobby when you win",
    Callback = function(state)
        if state then
            local player = game:GetService("Players").LocalPlayer
            if not player then return end
            
            if _G.returnToLobbyConn then
                _G.returnToLobbyConn:Disconnect()
                _G.returnToLobbyConn = nil
            end
            
            _G.returnToLobbyConn = player:GetPropertyChangedSignal("Team"):Connect(function()
                local winnerTeam = game:GetService("Teams"):FindFirstChild("Winner!")
                if player.Team == winnerTeam then
                    task.wait(1)
                    local restartBrick = workspace:FindFirstChild("Misc") and workspace.Misc:FindFirstChild("RestartBrick")
                    if restartBrick then
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.CFrame = restartBrick.CFrame + Vector3.new(0, 3, 0)
                        end
                    end
                end
            end)
        else
            if _G.returnToLobbyConn then
                _G.returnToLobbyConn:Disconnect()
                _G.returnToLobbyConn = nil
            end
        end
    end,
})

TowerBox:AddToggle("LoopAutoCompleteAllTowers", {
    Text    = "Auto Complete All Towers",
    Default = false,
    Tooltip = "Continuously auto-complete all towers in current region (requires Return to Lobby enabled)",
    Callback = function(state)
        local returnToLobbyToggle = Library.Toggles.AutoReturnToLobby
        local player = game:GetService("Players").LocalPlayer
        
        if state then
            _G.returnToLobbyOriginalState = returnToLobbyToggle.Value
            returnToLobbyToggle:SetValue(true)
            returnToLobbyToggle:SetDisabled(true)
            
            _G.autoCompleteAllTowersActive = true
            
            Library:Notify({ Title = "Auto Complete All Towers", Description = "Return to Lobby enabled and locked!", Duration = 3 })
            
            task.spawn(function()
                while _G.autoCompleteAllTowersActive do
                    local towerList = DropdownValues
                    
                    if not towerList or #towerList == 0 then
                        Library:Notify({ Title = "Auto Complete All Towers", Description = "No towers found!", Duration = 3 })
                        break
                    end
                    
                    for towerIndex, towerName in ipairs(towerList) do
                        if not _G.autoCompleteAllTowersActive then break end
                        
                        Library.Options.TowerSelect:SetValue(towerName)
                        Library:Notify({ Title = "Auto Complete All Towers", Description = "(" .. towerIndex .. "/" .. #towerList .. ") Preparing: " .. towerName, Duration = 2 })
                        task.wait(1)
                        
                        local startTeam = game:GetService("Teams"):FindFirstChild("Start")
                        local originalTeam = player.Team
                        
                        Library:Notify({ Title = "Auto Complete All Towers", Description = "(" .. towerIndex .. "/" .. #towerList .. ") Waiting for Auto Play... Press the button!", Duration = 5 })
                        
                        local maxWaitTime = 120
                        local waitStart = os.clock()
                        local enteredTower = false
                        
                        while _G.autoCompleteAllTowersActive and os.clock() - waitStart < maxWaitTime do
                            if player.Team ~= originalTeam and player.Team ~= startTeam then
                                enteredTower = true
                                Library:Notify({ Title = "Auto Complete All Towers", Description = "(" .. towerIndex .. "/" .. #towerList .. ") Entered tower! Playing...", Duration = 2 })
                                break
                            end
                            task.wait(0.5)
                        end
                        
                        if not enteredTower then
                            if os.clock() - waitStart >= maxWaitTime then
                                Library:Notify({ Title = "Auto Complete All Towers", Description = "Timeout waiting for Auto Play! Stopping.", Duration = 5 })
                            end
                            _G.autoCompleteAllTowersActive = false
                            break
                        end
                        
                        waitStart = os.clock()
                        maxWaitTime = 600
                        
                        while _G.autoCompleteAllTowersActive and os.clock() - waitStart < maxWaitTime do
                            if player.Team == startTeam then
                                Library:Notify({ Title = "Auto Complete All Towers", Description = "(" .. towerIndex .. "/" .. #towerList .. ") " .. towerName .. " completed! Ready for next tower.", Duration = 2 })
                                task.wait(1)
                                break
                            end
                            task.wait(1)
                        end
                        
                        if os.clock() - waitStart >= maxWaitTime then
                            Library:Notify({ Title = "Auto Complete All Towers", Description = "Timeout waiting for lobby! Stopping.", Duration = 5 })
                            _G.autoCompleteAllTowersActive = false
                            break
                        end
                    end
                    
                    if _G.autoCompleteAllTowersActive then
                        Library:Notify({ Title = "Auto Complete All Towers", Description = "Cycle completed! Restarting...", Duration = 3 })
                        task.wait(3)
                    end
                end
            end)
            
            Library:Notify({ Title = "Auto Complete All Towers", Description = "Started! Press Auto Play to begin each tower.", Duration = 3 })
        else
            _G.autoCompleteAllTowersActive = false
            
            local originalState = _G.returnToLobbyOriginalState or false
            returnToLobbyToggle:SetDisabled(false)
            returnToLobbyToggle:SetValue(originalState)
            
            Library:Notify({ Title = "Auto Complete All Towers", Description = "Stopped! Return to Lobby restored.", Duration = 2 })
        end
    end,
})

TowerBox:AddButton({
    Text     = "Auto Play",
    Callback = function()
        if isAutoPlaying then
            Library:Notify({ Title = "Auto Play", Description = "Already running!", Duration = 3 })
            return
        end
        local selected = Library.Options.TowerSelect.Value
        local config   = TowerConfigs[selected]
        if not config then
            Library:Notify({ Title = "Auto Play", Description = "No config for " .. selected, Duration = 3 })
            return
        end
        local Players      = game:GetService("Players")
        local TweenService = game:GetService("TweenService")
        local player       = Players.LocalPlayer
        local char         = player.Character
        if not char then
            Library:Notify({ Title = "Auto Play", Description = "Character not found!", Duration = 3 })
            return
        end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp      = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Library:Notify({ Title = "Auto Play", Description = "HumanoidRootPart not found!", Duration = 3 })
            return
        end
        isAutoPlaying = true
        Library.Toggles.Noclip:SetValue(true)
        Library.Toggles.Noclip:SetDisabled(true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        if humanoid.Sit then humanoid.Sit = false end
        humanoid.PlatformStand = true
        local RunService = game:GetService("RunService")
        local antiGravConn = RunService.Heartbeat:Connect(function()
            if hrp and hrp.Parent then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    hrp.AssemblyLinearVelocity.X,
                    0,
                    hrp.AssemblyLinearVelocity.Z
                )
            end
            local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Sit then h.Sit = false end
        end)
        local died = false
        local stopReason = "died"
        local diedConn
        diedConn = humanoid.Died:Connect(function()
            died = true
            stopReason = "died"
            diedConn:Disconnect()
        end)

        local exitButtonConn = nil
        local okBtn, exitBtn = pcall(function()
            return player.PlayerGui.Menu.wrapper.inner.exit.main.confirm.hitbox
        end)
        if okBtn and exitBtn then
            exitButtonConn = exitBtn.Activated:Connect(function()
                died = true
                stopReason = "exited"
            end)
        end

        local function stopAutoNoclip()
            if antiGravConn then
                antiGravConn:Disconnect()
                antiGravConn = nil
            end
            Library.Toggles.Noclip:SetDisabled(false)
            Library.Toggles.Noclip:SetValue(false)
            Library.Toggles.Fly:SetValue(false)
            if exitButtonConn then
                exitButtonConn:Disconnect()
                exitButtonConn = nil
            end
            task.wait(0.1)
            local c = game:GetService("Players").LocalPlayer.Character
            if c then
                local h = c:FindFirstChild("HumanoidRootPart")
                if h then
                    h.AssemblyLinearVelocity = Vector3.zero
                end
                local hum = c:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
                    hum.PlatformStand = false
                end
            end
        end

        local function checkDied()
            if died then
                local msg = stopReason == "exited" and "Exited, stopping!" or "Character died, stopping!"
                Library:Notify({ Title = "Auto Play", Description = msg, Duration = 3 })
                clearRouteHighlights()
                stopAutoNoclip()
                isAutoPlaying = false
                return true
            end
            return false
        end
        Library:Notify({ Title = "Auto Play", Description = "Fetching " .. selected .. " route...", Duration = 3 })

        if config.isTowerRush then
            local VirtualInputManager = game:GetService("VirtualInputManager")
            local ok, tpFrame = pcall(config.tpFrame)
            if not ok or not tpFrame then
                Library:Notify({ Title = "Auto Play", Description = selected .. " teleporter not found!", Duration = 3 })
                isAutoPlaying = false
                stopAutoNoclip()
                return
            end
            Library:Notify({ Title = "Auto Play", Description = "Fetching " .. selected .. " tower list...", Duration = 3 })
            local r1trSrc
            local okFetch = pcall(function() r1trSrc = game:HttpGet(config.routeUrl) end)
            if not okFetch or not r1trSrc then
                Library:Notify({ Title = "Auto Play", Description = selected .. " fetch failed!", Duration = 5 })
                isAutoPlaying = false
                stopAutoNoclip()
                return
            end
            local r1trFn = loadstring(r1trSrc)
            if not r1trFn then
                Library:Notify({ Title = "Auto Play", Description = selected .. " parse failed!", Duration = 5 })
                isAutoPlaying = false
                stopAutoNoclip()
                return
            end
            local okR1, getTowers = pcall(r1trFn)
            if not okR1 or type(getTowers) ~= "function" then
                Library:Notify({ Title = "Auto Play", Description = selected .. " load failed!", Duration = 5 })
                isAutoPlaying = false
                stopAutoNoclip()
                return
            end
            local okR2, towerList = pcall(getTowers)
            if not okR2 or type(towerList) ~= "table" then
                Library:Notify({ Title = "Auto Play", Description = selected .. " tower list failed!", Duration = 5 })
                isAutoPlaying = false
                stopAutoNoclip()
                return
            end
            Library:Notify({ Title = "Auto Play", Description = "Moving to " .. selected .. " teleporter...", Duration = 3 })
            local tpTouched = false
            local tpConn
            tpConn = tpFrame.Touched:Connect(function(hit)
                if hit:IsDescendantOf(char) and not tpTouched then
                    tpTouched = true
                    tpConn:Disconnect()
                end
            end)
            while not tpTouched do
                if checkDied() then return end
                hrp.CFrame = CFrame.new(tpFrame.Position + Vector3.new(0, 3, 0)) * (hrp.CFrame - hrp.CFrame.Position)
                task.wait(0.1)
            end
            if checkDied() then return end

            local totalSuggestedSec = 0
            for _, towerName in ipairs(towerList) do
                local st = SuggestedTimes[towerName]
                if st then
                    totalSuggestedSec = totalSuggestedSec + (tonumber(st.min) or 0) * 60 + (tonumber(st.sec) or 0)
                end
            end
            local useCustomTime = not Library.Toggles.UseSuggestedTime.Value
            local totalCustomSec = 0
            if useCustomTime then
                local cMin = tonumber(Library.Options.CompletionMin.Value) or 0
                local cSec = tonumber(Library.Options.CompletionSec.Value) or 0
                totalCustomSec = cMin * 60 + cSec
            end

            for towerIndex, towerName in ipairs(towerList) do
                if checkDied() then return end
                local towerConfig = TowerConfigs[towerName]
                if not towerConfig then continue end
                Library:Notify({ Title = "Auto Play", Description = "Fetching " .. towerName .. " route... (" .. towerIndex .. "/" .. #towerList .. ")", Duration = 3 })
                local routeSrc
                local okFetch = pcall(function() routeSrc = game:HttpGet(towerConfig.routeUrl) end)
                if not okFetch or not routeSrc then
                    Library:Notify({ Title = "Auto Play", Description = "Fetch failed for " .. towerName, Duration = 5 })
                    isAutoPlaying = false
                    stopAutoNoclip()
                    return
                end
                local towerSec
                if useCustomTime and totalSuggestedSec > 0 then
                    local st = SuggestedTimes[towerName]
                    local thisSuggestedSec = st and ((tonumber(st.min) or 0) * 60 + (tonumber(st.sec) or 0)) or 0
                    towerSec = totalCustomSec * (thisSuggestedSec / totalSuggestedSec)
                else
                    local tMin = tonumber(SuggestedTimes[towerName].min) or 3
                    local tSec = tonumber(SuggestedTimes[towerName].sec) or 0
                    towerSec = tMin * 60 + tSec
                end
                local towerDeadline = os.clock() + math.max(towerSec, 1)
                Library:Notify({ Title = "Auto Play", Description = "Entering " .. towerName .. "...", Duration = 3 })
                if towerIndex > 1 then
                    local ok2, teleportTo = pcall(towerConfig.teleportTo)
                    if not ok2 or not teleportTo then
                        Library:Notify({ Title = "Auto Play", Description = towerName .. " TeleportTo not found!", Duration = 3 })
                        isAutoPlaying = false
                        stopAutoNoclip()
                        return
                    end
                    Library:Notify({ Title = "Auto Play", Description = "Waiting for " .. towerName .. " teleport...", Duration = 3 })
                    local touched = false
                    local conn
                    conn = teleportTo.Touched:Connect(function(hit)
                        if hit:IsDescendantOf(char) and not touched then
                            touched = true
                            conn:Disconnect()
                        end
                    end)
                    while not touched do
                        if checkDied() then return end
                        local distToTP = (hrp.Position - teleportTo.Position).Magnitude
                        if distToTP < 10 then
                            touched = true
                            conn:Disconnect()
                            break
                        end
                        hrp.CFrame = teleportTo.CFrame + Vector3.new(0, 3, 0)
                        task.wait(0.1)
                    end
                    if checkDied() then return end
                end
                local posBeforeTP = hrp.Position
                task.wait(0.5)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                repeat
                    if checkDied() then
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                        return
                    end
                    task.wait(0.1)
                    char = player.Character
                    hrp  = char and char:FindFirstChild("HumanoidRootPart")
                until hrp and (hrp.Position - posBeforeTP).Magnitude > 0.1
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                if checkDied() then return end
                local fn, fnErr = loadstring(routeSrc)
                if not fn then
                    Library:Notify({ Title = "Auto Play", Description = towerName .. " parse failed: " .. tostring(fnErr), Duration = 5 })
                    isAutoPlaying = false
                    stopAutoNoclip()
                    return
                end
                local ok3, getCheckpoints = pcall(fn)
                if not ok3 or type(getCheckpoints) ~= "function" then
                    Library:Notify({ Title = "Auto Play", Description = towerName .. " load failed!", Duration = 5 })
                    isAutoPlaying = false
                    stopAutoNoclip()
                    return
                end
                local checkpoints
                repeat
                    if checkDied() then return end
                    local ok4, result = pcall(getCheckpoints)
                    if ok4 and type(result) == "table" and #result > 0 then
                        checkpoints = result
                    end
                    if not checkpoints then task.wait(0.1) end
                until checkpoints
                local totalDistance = 0
                local prevPos = hrp.Position
                local resolvedSteps = {}
                for _, step in ipairs(checkpoints) do
                    if step == "jump" then
                        table.insert(resolvedSteps, { type = "jump" })
                        continue
                    end
                    local stepType = "tween"
                    local target
                    if typeof(step) == "Instance" then
                        target = step
                    elseif type(step) == "table" then
                        stepType = step.type or "tween"
                        target   = step.target
                    end
                    if target and target:IsA("BasePart") then
                        local destPos = getTopPos(target)
                        local dist    = (destPos - prevPos).Magnitude
                        totalDistance = totalDistance + dist
                        table.insert(resolvedSteps, { type = stepType, target = target, destPos = destPos, dist = dist })
                        prevPos = destPos
                    end
                end
                currentResolvedSteps = resolvedSteps
                if Library.Toggles.ShowRoute.Value then
                    showRoute(resolvedSteps)
                end
                Library:Notify({ Title = "Auto Play", Description = towerName .. " - Starting route, " .. #resolvedSteps .. " checkpoints", Duration = 3 })
                local remainingDistances = {}
                local cumDist = 0
                for i = #resolvedSteps, 1, -1 do
                    local s = resolvedSteps[i]
                    if s.type ~= "jump" then cumDist = cumDist + (s.dist or 0) end
                    remainingDistances[i] = cumDist
                end
                for i, step in ipairs(resolvedSteps) do
                    if checkDied() then return end
                    char = player.Character
                    hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then
                        Library:Notify({ Title = "Auto Play", Description = "Character lost, stopping!", Duration = 3 })
                        isAutoPlaying = false
                        stopAutoNoclip()
                        return
                    end
                    if step.type == "jump" then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then hum.Jump = true end
                        continue
                    end
                    local dist       = (step.destPos - hrp.Position).Magnitude
                    local timeLeft   = math.max(towerDeadline - os.clock(), 0.001)
                    local remainDist = remainingDistances[i]
                    local stepTime   = remainDist > 0 and (timeLeft * (dist / remainDist)) or 0.05
                    stepTime         = math.max(stepTime, 0.05)

                    local startRot   = hrp.CFrame - hrp.CFrame.Position
                    local startTime  = os.clock()
                    local moveTarget = step.target
                    local done       = false
                    local lastPos    = hrp.Position
                    local moveConn
                    moveConn = RunService.Heartbeat:Connect(function(dt)
                        if died then
                            done = true
                            moveConn:Disconnect()
                            return
                        end
                        local c = player.Character
                        local h = c and c:FindFirstChild("HumanoidRootPart")
                        if not h then
                            done = true
                            moveConn:Disconnect()
                            return
                        end
                        if (h.Position - lastPos).Magnitude > 10 then
                            task.wait(0.5)
                            lastPos = h.Position
                            startTime = os.clock()
                            return
                        end
                        lastPos = h.Position
                        local currentDest = step.destPos
                        if moveTarget and moveTarget.Parent then
                            currentDest = getTopPos(moveTarget)
                        end
                        local currentDist = (currentDest - h.Position).Magnitude
                        if currentDist <= 0.1 then
                            done = true
                            moveConn:Disconnect()
                            return
                        end
                        local speed = stepTime > 0 and (dist / stepTime) or 50
                        local moveDist = math.min(speed * dt, currentDist)
                        local rawDir = (currentDest - h.Position)
                        if rawDir.Magnitude < 0.001 then return end
                        local dir = rawDir.Unit
                        if dir ~= dir then return end -- nan check
                        h.CFrame = CFrame.new(h.Position + dir * moveDist)
                        lastPos = h.Position
                        if (os.clock() - startTime) >= stepTime then
                            h.CFrame = CFrame.new(currentDest)
                            done = true
                            moveConn:Disconnect()
                        end
                    end)
                    repeat task.wait() until done
                end
                Library:Notify({ Title = "Auto Play", Description = towerName .. " complete!", Duration = 3 })
            end
            if not died then
                Library:Notify({ Title = "Auto Play", Description = selected .. " Complete!", Duration = 5 })
                clearRouteHighlights()
            end
            stopAutoNoclip()
            isAutoPlaying = false
            return
        end

        local routeSrc
        local ok0, err0 = pcall(function()
            routeSrc = game:HttpGet(config.routeUrl)
        end)
        if not ok0 or not routeSrc then
            Library:Notify({ Title = "Auto Play", Description = "Fetch failed: " .. tostring(err0), Duration = 5 })
            isAutoPlaying = false
            return
        end
        local ok, tpFrame = pcall(config.tpFrame)
        if not ok or not tpFrame then
            Library:Notify({ Title = "Auto Play", Description = selected .. " teleporter not found!", Duration = 3 })
            isAutoPlaying = false
            return
        end
        Library:Notify({ Title = "Auto Play", Description = "Moving to " .. selected .. " teleporter...", Duration = 3 })
        local tpTouched = false
        local tpConn
        tpConn = tpFrame.Touched:Connect(function(hit)
            if hit:IsDescendantOf(char) and not tpTouched then
                tpTouched = true
                tpConn:Disconnect()
            end
        end)
        while not tpTouched do
            if checkDied() then return end
            hrp.CFrame = CFrame.new(tpFrame.Position + Vector3.new(0, 3, 0)) * (hrp.CFrame - hrp.CFrame.Position)
            task.wait(0.1)
        end
        if checkDied() then return end
        local ok2, teleportTo = pcall(config.teleportTo)
        if not ok2 or not teleportTo then
            Library:Notify({ Title = "Auto Play", Description = "TeleportTo not found!", Duration = 3 })
            isAutoPlaying = false
            return
        end
        Library:Notify({ Title = "Auto Play", Description = "Waiting for teleport...", Duration = 3 })
        local touched = false
        local connection
        connection = teleportTo.Touched:Connect(function(hit)
            if hit:IsDescendantOf(char) and not touched then
                touched = true
                connection:Disconnect()
            end
        end)
        while not touched do
            if checkDied() then return end
            hrp.CFrame = teleportTo.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.1)
        end
        if checkDied() then return end
        local totalMin  = tonumber(Library.Options.CompletionMin.Value) or 0
        local totalSec  = tonumber(Library.Options.CompletionSec.Value) or 0
        local totalTime = totalMin * 60 + totalSec
        local deadline  = os.clock() + math.max(totalTime, 1)
        Library:Notify({ Title = "Auto Play", Description = "Waiting for teleport to complete...", Duration = 3 })
        local posBeforeTP = hrp.Position
        local VirtualInputManager = game:GetService("VirtualInputManager")
        task.wait(0.5)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
        repeat
            if checkDied() then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                return
            end
            task.wait(0.1)
            char = player.Character
            hrp  = char and char:FindFirstChild("HumanoidRootPart")
        until hrp and (hrp.Position - posBeforeTP).Magnitude > 0.1
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        if checkDied() then return end
        Library:Notify({ Title = "Auto Play", Description = "Loading " .. selected .. " route...", Duration = 3 })
        local fn, fnErr = loadstring(routeSrc)
        if not fn then
            Library:Notify({ Title = "Auto Play", Description = "Parse failed: " .. tostring(fnErr), Duration = 5 })
            isAutoPlaying = false
            return
        end
        local ok1, getCheckpoints = pcall(fn)
        if not ok1 or type(getCheckpoints) ~= "function" then
            Library:Notify({ Title = "Auto Play", Description = "Load failed: " .. tostring(getCheckpoints), Duration = 5 })
            isAutoPlaying = false
            return
        end
        local checkpoints
        local lastErr = ""
        local lastNotify = os.clock()
        repeat
            if checkDied() then return end
            local ok2b, result = pcall(getCheckpoints)
            if ok2b and type(result) == "table" and #result > 0 then
                checkpoints = result
            elseif not ok2b then
                lastErr = tostring(result)
                if os.clock() - lastNotify > 3 then
                    lastNotify = os.clock()
                    Library:Notify({ Title = "Auto Play", Description = "Retrying: " .. lastErr, Duration = 3 })
                end
            end
            if not checkpoints then task.wait(0.1) end
        until checkpoints
        local totalDistance = 0
        local prevPos = hrp.Position
        local resolvedSteps = {}
        for _, step in ipairs(checkpoints) do
            if step == "jump" then
                table.insert(resolvedSteps, { type = "jump" })
                continue
            end
            local stepType = "tween"
            local target
            if typeof(step) == "Instance" then
                target = step
            elseif type(step) == "table" then
                stepType = step.type or "tween"
                target   = step.target
            end
            if target and target:IsA("BasePart") then
                local destPos = getTopPos(target)
                local dist    = (destPos - prevPos).Magnitude
                totalDistance = totalDistance + dist
                table.insert(resolvedSteps, { type = stepType, target = target, destPos = destPos, dist = dist })
                prevPos = destPos
            end
        end
        currentResolvedSteps = resolvedSteps
        if Library.Toggles.ShowRoute.Value then
            showRoute(resolvedSteps)
        end
        local remainingTime = math.max(deadline - os.clock(), 1)
        Library:Notify({ Title = "Auto Play", Description = "Starting route, " .. #resolvedSteps .. " checkpoints", Duration = 3 })
        local remainingDistances = {}
        local cumDist = 0
        for i = #resolvedSteps, 1, -1 do
            local s = resolvedSteps[i]
            if s.type ~= "jump" then
                cumDist = cumDist + (s.dist or 0)
            end
            remainingDistances[i] = cumDist
        end
        for i, step in ipairs(resolvedSteps) do
            if checkDied() then return end
            char = player.Character
            hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                Library:Notify({ Title = "Auto Play", Description = "Character lost, stopping!", Duration = 3 })
                isAutoPlaying = false
                return
            end
            if step.type == "jump" then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
                continue
            end
            local dist         = (step.destPos - hrp.Position).Magnitude
            local timeLeft     = math.max(deadline - os.clock(), 0.001)
            local remainDist   = remainingDistances[i]
            local stepTime     = remainDist > 0 and (timeLeft * (dist / remainDist)) or 0.05
            stepTime           = math.max(stepTime, 0.05)

            local startTime  = os.clock()
            local moveTarget = step.target
            local isMoving   = moveTarget and moveTarget.Parent and
                               (getTopPos(moveTarget) - step.destPos).Magnitude > 0.5
            local done       = false

            if not isMoving then
                local dest = CFrame.new(step.destPos) * (hrp.CFrame - hrp.CFrame.Position)
                local tween = TweenService:Create(hrp, TweenInfo.new(stepTime, Enum.EasingStyle.Linear), { CFrame = dest })
                tween:Play()
                tween.Completed:Connect(function() done = true end)
                repeat task.wait() until done or died
                tween:Cancel()
            else
                local touchConn
                if moveTarget then
                    touchConn = moveTarget.Touched:Connect(function(hit)
                        local c = player.Character
                        if c and hit:IsDescendantOf(c) then
                            done = true
                        end
                    end)
                end
                local moveConn
                moveConn = RunService.Heartbeat:Connect(function(dt)
                    if died then done = true moveConn:Disconnect() return end
                    local c = player.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    if not h then done = true moveConn:Disconnect() return end
                    local currentDest = step.destPos
                    if moveTarget and moveTarget.Parent then
                        currentDest = getTopPos(moveTarget)
                    end
                    local currentDist = (currentDest - h.Position).Magnitude
                    if currentDist <= 0.1 then done = true moveConn:Disconnect() return end
                    local speed = stepTime > 0 and (dist / stepTime) or 50
                    local moveDist = math.min(speed * dt, currentDist)
                    local rawDir = (currentDest - h.Position)
                    if rawDir.Magnitude < 0.001 then return end
                    local dir = rawDir.Unit
                    if dir ~= dir then return end
                    h.CFrame = CFrame.new(h.Position + dir * moveDist)
                    if (os.clock() - startTime) >= stepTime then
                        h.CFrame = CFrame.new(currentDest)
                        done = true
                        moveConn:Disconnect()
                    end
                end)
                repeat task.wait() until done
                if moveConn then moveConn:Disconnect() end
                if touchConn then touchConn:Disconnect() end
            end
        end
        if not died then
            Library:Notify({ Title = "Auto Play", Description = "Complete!", Duration = 3 })
            clearRouteHighlights()
        end
        stopAutoNoclip()
        isAutoPlaying = false
        currentResolvedSteps = nil
    end,
})
local allJumpCheckpoints = {}
local allJumpVisuals = {}

AllJumpBox:AddToggle("AllJumpMode", {
    Text    = "Enable All Jump Mode",
    Default = false,
    Tooltip = "Place checkpoints and teleport back to them",
    Callback = function(state)
        if not state then
            for _, v in ipairs(allJumpVisuals) do
                if v and v.Parent then v:Destroy() end
            end
            allJumpCheckpoints = {}
            allJumpVisuals = {}
        end
    end,
})

local function allJumpPlace()
    if not Library.Toggles.AllJumpMode.Value then return end
    local char = game:GetService("Players").LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    table.insert(allJumpCheckpoints, hrp.CFrame)
    local part = Instance.new("Part")
    part.Size         = hrp.Size
    part.CFrame       = hrp.CFrame
    part.Anchored     = true
    part.CanCollide   = false
    part.Transparency = 0.5
    part.Material     = Enum.Material.Neon
    part.Color        = Color3.fromRGB(255, 255, 255)
    part.Parent       = workspace
    table.insert(allJumpVisuals, part)
end

local function allJumpRemove()
    if not Library.Toggles.AllJumpMode.Value then return end
    if #allJumpCheckpoints > 0 then
        table.remove(allJumpCheckpoints)
        local v = table.remove(allJumpVisuals)
        if v then v:Destroy() end
    end
end

local function allJumpTeleport()
    if not Library.Toggles.AllJumpMode.Value then return end
    if #allJumpCheckpoints == 0 then return end
    local char = game:GetService("Players").LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = allJumpCheckpoints[#allJumpCheckpoints]
    end
end

local kb_AJPlace = AllJumpBox:AddLabel("Place"):AddKeyPicker("AJPlace", {
    Text    = "Place",
    Default = "Q",
    Mode    = "Press",
})
Options.AJPlace:OnClick(allJumpPlace)

local kb_AJRemove = AllJumpBox:AddLabel("Remove"):AddKeyPicker("AJRemove", {
    Text    = "Remove",
    Default = "T",
    Mode    = "Press",
})
Options.AJRemove:OnClick(allJumpRemove)

local kb_AJTeleport = AllJumpBox:AddLabel("Teleport"):AddKeyPicker("AJTeleport", {
    Text    = "Teleport",
    Default = "R",
    Mode    = "Press",
})
Options.AJTeleport:OnClick(allJumpTeleport)

local PlayerBox = Tabs.Main:AddRightGroupbox("Player")

local wsConn = nil
local wsCAConn = nil
local jpConn = nil
local jpCAConn = nil

local function applyCharacterStats(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        char:WaitForChild("Humanoid", 5)
        hum = char:FindFirstChildOfClass("Humanoid")
    end
    if hum then
        hum.WalkSpeed = Library.Options.WalkSpeed.Value
        hum.JumpPower = Library.Options.JumpPower.Value
    end
end

game:GetService("Players").LocalPlayer.CharacterAdded:Connect(applyCharacterStats)

PlayerBox:AddSlider("WalkSpeed", {
    Text     = "Walk Speed",
    Default  = 16,
    Min      = 0,
    Max      = 100,
    Rounding = 0,
    Callback = function(value)
        local char = game:GetService("Players").LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = value end
    end,
})

PlayerBox:AddToggle("LockWalkSpeed", {
    Text    = "Lock Walk Speed",
    Default = false,
    Callback = function(state)
        local player = game:GetService("Players").LocalPlayer
        if wsConn then wsConn:Disconnect() wsConn = nil end
        if wsCAConn then wsCAConn:Disconnect() wsCAConn = nil end
        if not state then return end
        local function applyWS(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then
                char:WaitForChild("Humanoid", 5)
                hum = char:FindFirstChildOfClass("Humanoid")
            end
            if not hum then return end
            hum.WalkSpeed = Library.Options.WalkSpeed.Value
            wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if Library.Toggles.LockWalkSpeed.Value then
                    hum.WalkSpeed = Library.Options.WalkSpeed.Value
                end
            end)
        end
        applyWS(player.Character)
        wsCAConn = player.CharacterAdded:Connect(function(char)
            if wsConn then wsConn:Disconnect() wsConn = nil end
            applyWS(char)
        end)
    end,
})

PlayerBox:AddSlider("JumpPower", {
    Text     = "Jump Power",
    Default  = 50,
    Min      = 0,
    Max      = 200,
    Rounding = 0,
    Callback = function(value)
        local char = game:GetService("Players").LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = value end
    end,
})

PlayerBox:AddToggle("LockJumpPower", {
    Text    = "Lock Jump Power",
    Default = false,
    Callback = function(state)
        local player = game:GetService("Players").LocalPlayer
        if jpConn then jpConn:Disconnect() jpConn = nil end
        if jpCAConn then jpCAConn:Disconnect() jpCAConn = nil end
        if not state then return end
        local function applyJP(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then
                char:WaitForChild("Humanoid", 5)
                hum = char:FindFirstChildOfClass("Humanoid")
            end
            if not hum then return end
            hum.JumpPower = Library.Options.JumpPower.Value
            jpConn = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if Library.Toggles.LockJumpPower.Value then
                    hum.JumpPower = Library.Options.JumpPower.Value
                end
            end)
        end
        applyJP(player.Character)
        jpCAConn = player.CharacterAdded:Connect(function(char)
            if jpConn then jpConn:Disconnect() jpConn = nil end
            applyJP(char)
        end)
    end,
})

PlayerBox:AddButton({
    Text     = "Reset Walk Speed & Jump Power",
    Callback = function()
        Library.Options.WalkSpeed:SetValue(16)
        Library.Options.JumpPower:SetValue(50)
    end,
})
PlayerBox:AddDivider()
PlayerBox:AddToggle("Noclip", {
    Text    = "Noclip",
    Default = false,
    Tooltip = "Walk through walls",
    Callback = function(state)
        local Players = game:GetService("Players")
        if state then
            local RunService = game:GetService("RunService")
            noclipConnection = RunService.Stepped:Connect(function()
                local char = Players.LocalPlayer.Character
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide == true and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = false
                    end
                end
            end)
        else
            if noclipConnection then
                noclipConnection:Disconnect()
                noclipConnection = nil
            end
        end
    end,
}):AddKeyPicker("NoclipKeybind", {
    Text            = "Noclip Keybind",
    Default         = "V",
    Mode            = "Toggle",
    SyncToggleState = true,
})
local flyConnection = nil
local flyInputBeganConn = nil
local flyInputEndedConn = nil
local function setFly(state)
    local Players  = game:GetService("Players")
    local player   = Players.LocalPlayer
    local char     = player.Character
    if not char then return end
    local hrp      = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    if state then
        local BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.Name       = "FlyVelocity"
        BodyVelocity.Velocity   = Vector3.zero
        BodyVelocity.MaxForce   = Vector3.new(1e9, 1e9, 1e9)
        BodyVelocity.Parent     = hrp
        local BodyGyro = Instance.new("BodyGyro")
        BodyGyro.Name       = "FlyGyro"
        BodyGyro.MaxTorque  = Vector3.new(1e9, 1e9, 1e9)
        BodyGyro.P          = 9e4
        BodyGyro.CFrame     = hrp.CFrame
        BodyGyro.Parent     = hrp

        local UserInputService = game:GetService("UserInputService")
        local RunService       = game:GetService("RunService")
        local SPEED = 50

        local CONTROL = { F = 0, B = 0, L = 0, R = 0, U = 0, D = 0 }

        flyInputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 1
            elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = -1
            elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = -1
            elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 1
            elseif input.KeyCode == Enum.KeyCode.Space then CONTROL.U = 1
            elseif input.KeyCode == Enum.KeyCode.LeftShift then CONTROL.D = -1
            end
        end)

        flyInputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
            if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 0
            elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = 0
            elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = 0
            elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 0
            elseif input.KeyCode == Enum.KeyCode.Space then CONTROL.U = 0
            elseif input.KeyCode == Enum.KeyCode.LeftShift then CONTROL.D = 0
            end
        end)

        flyConnection = RunService.Heartbeat:Connect(function()
            local newChar = player.Character
            local newHrp  = newChar and newChar:FindFirstChild("HumanoidRootPart")
            if newHrp ~= hrp then
                -- Character respawned, reinitialize
                hrp      = newHrp
                char     = newChar
                humanoid = newChar and newChar:FindFirstChildOfClass("Humanoid")
                if hrp then
                    if not hrp:FindFirstChild("FlyVelocity") then
                        local bv2 = Instance.new("BodyVelocity")
                        bv2.Name     = "FlyVelocity"
                        bv2.Velocity = Vector3.zero
                        bv2.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                        bv2.Parent   = hrp
                    end
                    if not hrp:FindFirstChild("FlyGyro") then
                        local bg2 = Instance.new("BodyGyro")
                        bg2.Name      = "FlyGyro"
                        bg2.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
                        bg2.P         = 9e4
                        bg2.CFrame    = hrp.CFrame
                        bg2.Parent    = hrp
                    end
                end
            end
            hrp      = newHrp
            humanoid = newChar and newChar:FindFirstChildOfClass("Humanoid")
            local bv = hrp and hrp:FindFirstChild("FlyVelocity")
            local bg = hrp and hrp:FindFirstChild("FlyGyro")
            if not bv or not bg then return end
            if humanoid then humanoid.PlatformStand = true end
            local cam = workspace.CurrentCamera
            local moveDir = (cam.CFrame.LookVector * (CONTROL.F + CONTROL.B))
                          + (cam.CFrame.RightVector * (CONTROL.L + CONTROL.R))
                          + (Vector3.new(0, 1, 0) * (CONTROL.U + CONTROL.D))
            bv.Velocity = moveDir * SPEED
            bg.CFrame   = cam.CFrame
        end)
    else
        if flyConnection then
            flyConnection:Disconnect()
            flyConnection = nil
        end
        if flyInputBeganConn then
            flyInputBeganConn:Disconnect()
            flyInputBeganConn = nil
        end
        if flyInputEndedConn then
            flyInputEndedConn:Disconnect()
            flyInputEndedConn = nil
        end
        local hrp2 = char:FindFirstChild("HumanoidRootPart")
        if hrp2 then
            local bv = hrp2:FindFirstChild("FlyVelocity")
            local bg = hrp2:FindFirstChild("FlyGyro")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            hrp2.AssemblyLinearVelocity = Vector3.zero
        end
        if humanoid then humanoid.PlatformStand = false end
    end
end
local FlyToggle = PlayerBox:AddToggle("Fly", {
    Text    = "Fly",
    Default = false,
    Tooltip = "Toggle fly mode",
    Callback = function(state)
        setFly(state)
    end,
})
FlyToggle:AddKeyPicker("FlyKeybind", {
    Text             = "Fly Keybind",
    Default          = "F",
    Mode             = "Toggle",
    SyncToggleState  = true,
})

PlayerBox:AddToggle("InfiniteJump", {
    Text    = "Infinite Jump",
    Default = false,
    Callback = function(state)
        if state then
            local Players = game:GetService("Players")
            local UIS     = game:GetService("UserInputService")
            _G.InfiniteJumpConn = UIS.JumpRequest:Connect(function()
                local char = Players.LocalPlayer.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        else
            if _G.InfiniteJumpConn then
                _G.InfiniteJumpConn:Disconnect()
                _G.InfiniteJumpConn = nil
            end
        end
    end,
})
local godmodeOriginal = nil
local godmodeV2Connection = nil
local godmodeKillBrickConn = nil
local godmodeKillBrickParts = {}

local function isKillBrickPart(inst)
    if not inst:IsA("BasePart") then return false end
    if inst.Name == "Kill Brick" then return true end
    local kills = inst:FindFirstChild("kills")
    if kills and kills:IsA("BoolValue") then return true end
    return false
end

local function disableGodmode()
    if godmodeOriginal then
        hookmetamethod(game, "__namecall", godmodeOriginal)
        godmodeOriginal = nil
    end
    if godmodeV2Connection then
        godmodeV2Connection:Disconnect()
        godmodeV2Connection = nil
    end
    if godmodeKillBrickConn then
        godmodeKillBrickConn:Disconnect()
        godmodeKillBrickConn = nil
    end
    for part in pairs(godmodeKillBrickParts) do
        if part and part.Parent then
            part.CanTouch = true
        end
    end
    godmodeKillBrickParts = {}
end

PlayerBox:AddToggle("Godmode", {
    Text    = "Godmode",
    Default = true,
    Tooltip = "Prevents taking damage",
    Callback = function(state)
        disableGodmode()
        if not state then
            return
        end
        local mode = Library.Options.GodmodeMode.Value
        if mode == "hookmetamethod" then
            if not sUNCSupport.Godmode then
                Library.Toggles.Godmode:SetValue(false)
                return
            end
            local damageEvent = game:GetService("ReplicatedStorage"):WaitForChild("DamageEvent")
            godmodeOriginal = hookmetamethod(game, "__namecall", function(self, ...)
                if self == damageEvent and getnamecallmethod() == "FireServer" then
                    return
                end
                return godmodeOriginal(self, ...)
            end)
        elseif mode == "DamageEvent" then
            local Players    = game:GetService("Players")
            local RunService = game:GetService("RunService")
            local damageEvent = game:GetService("ReplicatedStorage"):WaitForChild("DamageEvent")
            godmodeV2Connection = RunService.Heartbeat:Connect(function()
                local char = Players.LocalPlayer.Character
                if not char then return end
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health < humanoid.MaxHealth then
                    damageEvent:FireServer(-humanoid.MaxHealth)
                end
            end)
        elseif mode == "CanTouch" then
            local function scanAndDisable(inst)
                if isKillBrickPart(inst) and inst.CanTouch then
                    inst.CanTouch = false
                    godmodeKillBrickParts[inst] = true
                end
            end
            for _, inst in ipairs(workspace:GetDescendants()) do
                scanAndDisable(inst)
            end
            godmodeKillBrickConn = workspace.DescendantAdded:Connect(scanAndDisable)
        end
    end,
})

PlayerBox:AddDropdown("GodmodeMode", {
    Text    = "Godmode Mode",
    Values  = { "hookmetamethod", "DamageEvent", "CanTouch" },
    Default = sUNCSupport.Godmode and "hookmetamethod" or "DamageEvent",
    Callback = function(value)
        disableGodmode()
        if Library.Toggles.Godmode.Value then
            Library.Toggles.Godmode:SetValue(false)
            Library.Toggles.Godmode:SetValue(true)
        end
    end,
})

if not sUNCSupport.Godmode then
    Library.Options.GodmodeMode:SetDisabledValues({ "hookmetamethod" })
end

Library.Toggles.Godmode:SetValue(true)

Library.Toggles.UseSuggestedTime:SetValue(true)
local MenuGroup = Tabs.UISettings:AddLeftGroupbox("Menu")
MenuGroup:AddDropdown("UIStyle", {
    Text    = "UI Style",
    Values  = { "Obsidian", "Linoria" },
    Default = uiStyle,
    Callback = function(value)
        pcall(function()
            if not isfolder("ProjectEToHScript") then
                makefolder("ProjectEToHScript")
            end
            writefile(uiStyleFile, value)
        end)
        Library:Notify({ Title = "UI Style", Description = "Will apply on next launch!", Duration = 3 })
    end,
})
MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})
MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})
MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        local DPI = tonumber(Value)
        Library:SetDPIScale(DPI)
    end,
})
local isObsidian = repo:find("deividcomsono") ~= nil

if isObsidian then
    MenuGroup:AddSlider("UICornerSlider", {
        Text = "Corner Radius",
        Default = Library.CornerRadius,
        Min = 0,
        Max = 20,
        Rounding = 0,
        Callback = function(value)
            Window:SetCornerRadius(value)
        end
    })
end
MenuGroup:AddToggle("AutoExecute", {
    Text    = "Auto Execute on Teleport",
    Default = autoExecuteDefault,
    Tooltip = sUNCSupport.queueteleport and "Re-executes this script after teleporting" or "Not supported by this executor",
    Callback = function(state)
        if not sUNCSupport.queueteleport then
            Library:Notify({ Title = "Auto Execute", Description = "queue_on_teleport not supported!", Duration = 3 })
            Library.Toggles.AutoExecute:SetValue(false)
            return
        end
        pcall(function()
            if not isfolder("ProjectEToHScript") then makefolder("ProjectEToHScript") end
            writefile(autoExecuteFile, tostring(state))
        end)
        if state then
            queueteleport([[
                local uiStyle = "Obsidian"
                pcall(function()
                    if isfile("ProjectEToHScript/ui_style.txt") then
                        uiStyle = readfile("ProjectEToHScript/ui_style.txt")
                    end
                end)
                SCRIPT_KEY = "KEYLESS"
                loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/0541c1dfb789f231c7d85e04604e4146558377cc11d3c771c043d7bfce8d9c03/download"))()
            ]])
        end
    end,
})
if not sUNCSupport.queueteleport then
    Library.Toggles.AutoExecute:SetDisabled(true)
end
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function()
    _G.ProjectEToHLoaded = nil
    Library:Unload()
end)
Library.ToggleKeybind = Options.MenuKeybind


ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("ProjectEToHScript")
SaveManager:IgnoreThemeSettings()
ThemeManager:ApplyToTab(Tabs.UISettings)
SaveManager:BuildConfigSection(Tabs.UISettings)
SaveManager:LoadAutoloadConfig()
_G.ProjectEToHLoaded = true
