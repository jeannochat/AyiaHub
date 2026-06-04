local HUB = "Ayia Hub"

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

local C = Color3.fromRGB
local U = UDim2.new
local D = UDim.new

local colors = {
    bg = C(20, 18, 22),
    panel = C(27, 24, 30),
    panel2 = C(35, 30, 38),
    stroke = C(255, 82, 175),
    accent = C(255, 92, 185),
    accent2 = C(255, 134, 207),
    text = C(255, 245, 252),
    muted = C(210, 182, 200),
    danger = C(255, 80, 95),
    success = C(90, 235, 145),
    blue = C(70, 170, 255),
    yellow = C(245, 255, 75),
}

local previous = PlayerGui:FindFirstChild("AyiaHub")
if previous then
    previous:Destroy()
end

local state = {
    playerESP = false,
    gunESP = false,
    trapESP = false,
    hideOwnESP = false,
    autoGetGun = false,
    ignoreKnifeThrows = false,
    instakillShoot = false,
    spawnKnifeNearPlayer = false,
    autoKnifeThrow = false,
    killAura = false,
    infiniteJump = false,
    ctrlClickTeleport = false,
    fly = false,
    loopWalkSpeed = false,
    loopFov = false,
    hitboxExpander = false,
    loopHitbox = false,
    walkSpeed = 16,
    jumpPower = 50,
    flySpeed = 80,
    fov = 70,
    hitboxSize = 8,
    shootOffset = 2.8,
    offsetToPingMult = 1,
}

local connections = {}
local playerData = {}
local espGroups = {}
local originalHitboxes = {}
local timerText
local flyVelocity
local flyGyro

local function make(className, props, parent)
    local object = Instance.new(className)

    for key, value in pairs(props or {}) do
        object[key] = value
    end

    if parent then
        object.Parent = parent
    end

    return object
end

local gui = make("ScreenGui", {
    Name = "AyiaHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local espRoot = make("Folder", { Name = "AyiaESP" }, gui)

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = HUB,
            Text = tostring(text),
            Duration = 4,
        })
    end)
end

local function safeRun(callback, ...)
    local ok, err = pcall(callback, ...)

    if not ok then
        warn("[Ayia Hub]", err)
        notify("Erro no modulo. Veja o console.")
    end
end

local function disconnect(name)
    if connections[name] then
        connections[name]:Disconnect()
        connections[name] = nil
    end
end

local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(player)
    local character = getCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
    local character = getCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character.PrimaryPart
end

local function getToolOwner(toolName, skipLocal)
    for _, player in ipairs(Players:GetPlayers()) do
        if not (skipLocal and player == LocalPlayer) then
            local backpack = player:FindFirstChild("Backpack")
            local character = getCharacter(player)

            if backpack and backpack:FindFirstChild(toolName) then
                return player
            end

            if character and character:FindFirstChild(toolName) then
                return player
            end
        end
    end
end

local function findRole(roleName, skipLocal)
    local toolName = roleName == "Murderer" and "Knife" or "Gun"
    local toolOwner = getToolOwner(toolName, skipLocal)

    if toolOwner then
        return toolOwner
    end

    for playerName, data in pairs(playerData) do
        if data.Role == roleName then
            local player = Players:FindFirstChild(playerName)

            if player and not (skipLocal and player == LocalPlayer) then
                return player
            end
        end
    end
end

local function findMurderer()
    return findRole("Murderer", false)
end

local function findSheriff()
    return findRole("Sheriff", false)
end

local function findSheriffNotMe()
    return findRole("Sheriff", true)
end

local function findNearestPlayer()
    local root = getRoot(LocalPlayer)
    local nearest
    local shortest = math.huge

    if not root then
        return nil
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local otherRoot = getRoot(player)
            local humanoid = getHumanoid(player)

            if otherRoot and humanoid and humanoid.Health > 0 then
                local distance = (root.Position - otherRoot.Position).Magnitude

                if distance < shortest then
                    shortest = distance
                    nearest = player
                end
            end
        end
    end

    return nearest
end

local function getMap()
    for _, object in ipairs(workspace:GetChildren()) do
        if object:FindFirstChild("CoinContainer") and object:FindFirstChild("Spawns") then
            return object
        end
    end

    return nil
end

local function findGunDrop()
    local map = getMap()

    if map then
        local gun = map:FindFirstChild("GunDrop", true)

        if gun then
            return gun
        end
    end

    return workspace:FindFirstChild("GunDrop", true)
end

local function getAdorneePart(target)
    if not target then
        return nil
    end

    if target:IsA("BasePart") then
        return target
    end

    if target:IsA("Model") then
        return target:FindFirstChild("HumanoidRootPart")
            or target:FindFirstChild("UpperTorso")
            or target:FindFirstChildWhichIsA("BasePart")
            or target.PrimaryPart
    end
end

local function clearESP(group)
    if not espGroups[group] then
        return
    end

    for _, item in ipairs(espGroups[group]) do
        for _, instance in ipairs(item) do
            if instance and instance.Parent then
                instance:Destroy()
            end
        end
    end

    espGroups[group] = {}
end

local function addESP(group, target, color, label)
    if not gui.Parent then
        return
    end

    local part = getAdorneePart(target)

    if not target or not part then
        return
    end

    espGroups[group] = espGroups[group] or {}

    local highlight = make("Highlight", {
        Name = "AyiaHighlight",
        Adornee = target,
        FillColor = color,
        OutlineColor = color,
        FillTransparency = 0.55,
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    }, espRoot)

    local created = { highlight }

    if label then
        local billboard = make("BillboardGui", {
            Name = "AyiaLabel",
            Adornee = part,
            AlwaysOnTop = true,
            Size = U(0, 120, 0, 34),
            StudsOffset = Vector3.new(0, 3, 0),
        }, espRoot)

        local text = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = U(1, 0, 1, 0),
            Font = Enum.Font.GothamBold,
            Text = label,
            TextColor3 = color,
            TextScaled = true,
        }, billboard)

        make("UIStroke", {
            Color = C(12, 10, 14),
            Thickness = 2,
        }, text)

        table.insert(created, billboard)
    end

    table.insert(espGroups[group], created)
end

local function reloadPlayerESP()
    if not gui.Parent then
        return
    end

    clearESP("players")

    if not state.playerESP then
        return
    end

    local murderer = findMurderer()
    local sheriff = findSheriff()

    for _, player in ipairs(Players:GetPlayers()) do
        if not (player == LocalPlayer and state.hideOwnESP) then
            local character = getCharacter(player)

            if character then
                if player == murderer then
                    addESP("players", character, colors.danger, "Murderer")
                elseif player == sheriff then
                    addESP("players", character, colors.blue, "Sheriff")
                else
                    addESP("players", character, colors.success, "Innocent")
                end
            end
        end
    end
end

local function reloadGunESP()
    if not gui.Parent then
        return
    end

    clearESP("gun")

    if not state.gunESP then
        return
    end

    local gun = findGunDrop()

    if gun then
        addESP("gun", gun, colors.yellow, "Dropped gun")
    end
end

local function reloadTrapESP()
    if not gui.Parent then
        return
    end

    clearESP("traps")

    if not state.trapESP then
        return
    end

    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("BasePart") and object.Name == "Trap" then
            object.Transparency = 0
            addESP("traps", object, colors.danger, "Trap")
        end
    end
end

local function equipTool(toolName)
    local character = getCharacter(LocalPlayer)
    local humanoid = getHumanoid(LocalPlayer)
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    if not character or not humanoid then
        return nil
    end

    local tool = character:FindFirstChild(toolName) or (backpack and backpack:FindFirstChild(toolName))

    if tool and tool.Parent == backpack then
        humanoid:EquipTool(tool)
        task.wait()
    end

    return character:FindFirstChild(toolName) or tool
end

local function getPredictedPosition(player, offset)
    local root = getRoot(player)
    local humanoid = getHumanoid(player)

    if not root then
        return nil
    end

    offset = offset or state.shootOffset

    local velocity = root.AssemblyLinearVelocity or Vector3.new()
    local moveDirection = humanoid and humanoid.MoveDirection or Vector3.new()
    local pingMult = ((LocalPlayer:GetNetworkPing() * 1000) * ((state.offsetToPingMult - 1) * 0.01)) + 1
    local lead = ((velocity * Vector3.new(0.75, 0.5, 0.75)) * (offset / 15) + moveDirection * offset) * pingMult

    return root.Position + lead
end

local function shootMurderer()
    if findSheriff() ~= LocalPlayer then
        notify("Voce nao esta com a gun.")
        return
    end

    local target = findMurderer() or findSheriffNotMe()
    local targetRoot = getRoot(target)

    if not target or not targetRoot then
        notify("Nao achei o murderer.")
        return
    end

    local gun = equipTool("Gun")
    local character = getCharacter(LocalPlayer)

    if not gun or not character then
        notify("Gun nao encontrada.")
        return
    end

    local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or getRoot(LocalPlayer)
    local shootRemote = gun:FindFirstChild("Shoot")

    if not hand or not shootRemote then
        notify("Remote da gun nao encontrado.")
        return
    end

    local args

    if state.instakillShoot then
        args = {
            CFrame.new(targetRoot.Position + Vector3.new(0, 1, 0)),
            CFrame.new(targetRoot.Position),
        }
    else
        local predicted = getPredictedPosition(target, state.shootOffset)

        if not predicted then
            notify("Nao consegui prever a posicao.")
            return
        end

        args = {
            CFrame.new(hand.Position),
            CFrame.new(predicted),
        }
    end

    shootRemote:FireServer(unpack(args))
end

local function delayedShootMurderer()
    disconnect("delayedShoot")

    if findSheriff() ~= LocalPlayer then
        notify("Voce nao esta com a gun.")
        return
    end

    notify("Esperando linha de tiro...")

    connections.delayedShoot = RunService.Stepped:Connect(function()
        local target = findMurderer() or findSheriffNotMe()
        local targetRoot = getRoot(target)
        local root = getRoot(LocalPlayer)

        if not target or not targetRoot or not root then
            return
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { getCharacter(LocalPlayer) }

        local direction = targetRoot.Position - root.Position
        local result = workspace:Raycast(root.Position, direction, params)

        if not result or result.Instance:IsDescendantOf(getCharacter(target)) then
            disconnect("delayedShoot")
            shootMurderer()
        end
    end)
end

local function knifeThrow(silent)
    if findMurderer() ~= LocalPlayer then
        if not silent then
            notify("Voce nao e o murderer.")
        end

        return
    end

    local knife = equipTool("Knife")
    local target = findNearestPlayer()
    local targetRoot = getRoot(target)
    local character = getCharacter(LocalPlayer)

    if not knife or not character then
        if not silent then
            notify("Knife nao encontrada.")
        end

        return
    end

    if not target or not targetRoot then
        if not silent then
            notify("Nao achei jogador perto.")
        end

        return
    end

    local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or getRoot(LocalPlayer)
    local predicted = getPredictedPosition(target, state.shootOffset + 1)

    if not hand or not predicted then
        return
    end

    local args = {
        CFrame.new(hand.Position),
        CFrame.new(predicted),
    }

    if state.spawnKnifeNearPlayer then
        args[1] = CFrame.new(targetRoot.Position + targetRoot.CFrame.LookVector * 5)
    end

    local events = knife:FindFirstChild("Events")
    local thrown = events and events:FindFirstChild("KnifeThrown")

    if thrown then
        thrown:FireServer(unpack(args))
    elseif knife:FindFirstChild("Throw") then
        knife.Throw:FireServer(unpack(args))
    else
        if not silent then
            notify("Remote da knife nao encontrado.")
        end
    end
end

local function stab()
    local knife = equipTool("Knife")

    if not knife then
        notify("Knife nao encontrada.")
        return
    end

    local remote = knife:FindFirstChild("Stab")

    if remote then
        remote:FireServer("Slash")
    else
        notify("Remote Stab nao encontrado.")
    end
end

local function killClosest()
    if findMurderer() ~= LocalPlayer then
        notify("Voce nao e o murderer.")
        return
    end

    local target = findNearestPlayer()
    local targetRoot = getRoot(target)
    local root = getRoot(LocalPlayer)

    if not target or not targetRoot or not root then
        notify("Nao achei alvo perto.")
        return
    end

    targetRoot.Anchored = true
    targetRoot.CFrame = root.CFrame + root.CFrame.LookVector * 2
    task.wait(0.1)
    stab()
end

local function killEveryone()
    if findMurderer() ~= LocalPlayer then
        notify("Voce nao e o murderer.")
        return
    end

    local root = getRoot(LocalPlayer)

    if not root then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local targetRoot = getRoot(player)

        if player ~= LocalPlayer and targetRoot then
            targetRoot.Anchored = true
            targetRoot.CFrame = root.CFrame + root.CFrame.LookVector
        end
    end

    task.wait(0.1)
    stab()
end

local function holdEveryone()
    if findMurderer() ~= LocalPlayer then
        notify("Isso so ajuda se voce for murderer.")
        return
    end

    local root = getRoot(LocalPlayer)

    if not root then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local targetRoot = getRoot(player)

        if player ~= LocalPlayer and targetRoot then
            targetRoot.Anchored = true
            targetRoot.CFrame = root.CFrame + root.CFrame.LookVector * 5
        end
    end
end

local function teleportTo(part, restoreAfterPickup)
    local character = getCharacter(LocalPlayer)

    if not character or not part then
        return false
    end

    local oldPivot = character:GetPivot()
    character:PivotTo(part:GetPivot())

    if restoreAfterPickup then
        local done = false
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local con

        if backpack then
            con = backpack.ChildAdded:Connect(function()
                done = true
            end)
        end

        local started = os.clock()

        repeat
            task.wait()
        until done or os.clock() - started > 2

        if con then
            con:Disconnect()
        end

        character:PivotTo(oldPivot)
    end

    return true
end

local function teleportDroppedGun()
    local gun = findGunDrop()

    if not gun then
        notify("Nao tem gun dropada.")
        return
    end

    teleportTo(gun, true)
end

local function teleportLobby()
    local lobby = workspace:FindFirstChild("Lobby")

    if not lobby then
        notify("Lobby nao encontrado.")
        return
    end

    local spawn = lobby:FindFirstChild("Spawns") and lobby.Spawns:FindFirstChildWhichIsA("SpawnLocation")
    local target = spawn or lobby:FindFirstChildWhichIsA("BasePart", true)

    if target then
        getCharacter(LocalPlayer):MoveTo(target.Position)
    end
end

local function teleportMap()
    local map = getMap()

    if not map or not map:FindFirstChild("Spawns") then
        notify("Mapa nao encontrado.")
        return
    end

    local spawns = map.Spawns:GetChildren()

    if #spawns == 0 then
        return
    end

    local spawn = spawns[math.random(1, #spawns)]

    if spawn:IsA("BasePart") then
        getCharacter(LocalPlayer):MoveTo(spawn.Position)
    end
end

local function setRoundTimer(enabled)
    if enabled then
        if timerText then
            timerText:Destroy()
        end

        timerText = make("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = U(0.5, 0, 0.15, 0),
            Size = U(0, 220, 0, 36),
            Font = Enum.Font.GothamBold,
            TextColor3 = colors.text,
            TextScaled = true,
            Text = "",
        }, gui)

        make("UIStroke", {
            Color = C(12, 10, 14),
            Thickness = 2,
        }, timerText)

        connections.roundTimer = RunService.Heartbeat:Connect(function()
            local timerPart = workspace:FindFirstChild("RoundTimerPart")
            local seconds = timerPart and timerPart:GetAttribute("Time")

            if typeof(seconds) ~= "number" or seconds < 0 then
                timerText.Text = ""
                return
            end

            timerText.Text = string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
        end)
    else
        disconnect("roundTimer")

        if timerText then
            timerText:Destroy()
            timerText = nil
        end
    end
end

local function applyWalkSpeed()
    local humanoid = getHumanoid(LocalPlayer)

    if humanoid then
        humanoid.WalkSpeed = state.walkSpeed
    end
end

local function applyJumpPower()
    local humanoid = getHumanoid(LocalPlayer)

    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = state.jumpPower
    end
end

local function setInfiniteJump(enabled)
    state.infiniteJump = enabled
    disconnect("infiniteJump")

    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            local humanoid = getHumanoid(LocalPlayer)

            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

local function setCtrlClickTeleport(enabled)
    state.ctrlClickTeleport = enabled
    disconnect("ctrlClickTeleport")

    if enabled then
        connections.ctrlClickTeleport = Mouse.Button1Down:Connect(function()
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                local character = getCharacter(LocalPlayer)

                if character and Mouse.Hit then
                    character:MoveTo(Mouse.Hit.Position)
                end
            end
        end)
    end
end

local function setFly(enabled)
    state.fly = enabled
    disconnect("fly")

    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end

    if flyGyro then
        flyGyro:Destroy()
        flyGyro = nil
    end

    if not enabled then
        return
    end

    local root = getRoot(LocalPlayer)

    if not root then
        state.fly = false
        return
    end

    flyVelocity = make("BodyVelocity", {
        MaxForce = Vector3.new(1e5, 1e5, 1e5),
        Velocity = Vector3.new(),
    }, root)

    flyGyro = make("BodyGyro", {
        MaxTorque = Vector3.new(1e5, 1e5, 1e5),
        P = 9e4,
        CFrame = workspace.CurrentCamera.CFrame,
    }, root)

    connections.fly = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        local direction = Vector3.new()

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + camera.CFrame.LookVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - camera.CFrame.LookVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - camera.CFrame.RightVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + camera.CFrame.RightVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            direction = direction - Vector3.new(0, 1, 0)
        end

        if flyGyro then
            flyGyro.CFrame = camera.CFrame
        end

        if flyVelocity then
            flyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * state.flySpeed or Vector3.new()
        end
    end)
end

local function restoreHitboxes()
    for part, data in pairs(originalHitboxes) do
        if part and part.Parent then
            part.Size = data.Size
            part.Transparency = data.Transparency
            part.CanCollide = data.CanCollide
        end
    end

    originalHitboxes = {}
end

local function applyHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getRoot(player)

            if root then
                originalHitboxes[root] = originalHitboxes[root] or {
                    Size = root.Size,
                    Transparency = root.Transparency,
                    CanCollide = root.CanCollide,
                }

                root.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
                root.Transparency = 0.65
                root.CanCollide = false
            end
        end
    end
end

local function setHitboxExpander(enabled)
    state.hitboxExpander = enabled

    if enabled then
        applyHitboxes()
    else
        restoreHitboxes()
    end
end

local function setKillAura(enabled)
    state.killAura = enabled
    disconnect("killAura")

    if not enabled then
        return
    end

    connections.killAura = RunService.Heartbeat:Connect(function()
        if findMurderer() ~= LocalPlayer then
            return
        end

        local root = getRoot(LocalPlayer)

        if not root then
            return
        end

        for _, player in ipairs(Players:GetPlayers()) do
            local targetRoot = getRoot(player)

            if player ~= LocalPlayer and targetRoot and (targetRoot.Position - root.Position).Magnitude < 7 then
                targetRoot.Anchored = true
                targetRoot.CFrame = root.CFrame + root.CFrame.LookVector * 2
                task.wait(0.1)
                stab()
                break
            end
        end
    end)
end

local function godMode()
    local camera = workspace.CurrentCamera
    local character = getCharacter(LocalPlayer)
    local humanoid = getHumanoid(LocalPlayer)

    if not character or not humanoid then
        return
    end

    local cameraCFrame = camera.CFrame
    local newHumanoid = humanoid:Clone()

    newHumanoid.Parent = character
    LocalPlayer.Character = nil
    humanoid:Destroy()
    LocalPlayer.Character = character
    camera.CameraSubject = newHumanoid
    camera.CFrame = cameraCFrame
    newHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    newHumanoid.Health = newHumanoid.MaxHealth

    local animate = character:FindFirstChild("Animate")

    if animate then
        animate.Disabled = true
        task.wait()
        animate.Disabled = false
    end
end

local function sendRolesToChat()
    local murderer = findMurderer()
    local sheriff = findSheriff()
    local message = string.format(
        "Murderer: %s | Sheriff: %s | <<%s>>",
        murderer and murderer.Name or "-",
        sheriff and sheriff.Name or "-",
        HUB
    )

    local channels = TextChatService:FindFirstChild("TextChannels")

    if not channels then
        notify("TextChatService nao encontrado.")
        return
    end

    for _, channel in ipairs(channels:GetChildren()) do
        if channel.Name ~= "RBXSystem" then
            local ok = pcall(function()
                channel:SendAsync(message)
            end)

            if ok then
                return
            end
        end
    end

    notify("Nao consegui enviar no chat.")
end

local function copyName(player, roleName)
    if not player then
        notify("Nao achei " .. roleName .. ".")
        return
    end

    if setclipboard then
        setclipboard(player.Name)
        notify("Copiado: " .. player.Name)
    else
        notify(player.Name)
    end
end

local function antiAfk()
    if connections.antiAfk then
        notify("Anti AFK ja esta ligado.")
        return
    end

    connections.antiAfk = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
    end)

    notify("Anti AFK ligado.")
end

local function fpsBoost()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9

    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Material = Enum.Material.SmoothPlastic
            object.Reflectance = 0
        elseif object:IsA("Decal") or object:IsA("Texture") then
            object.Transparency = 1
        elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Smoke") or object:IsA("Fire") then
            object.Enabled = false
        end
    end

    notify("FPS Boost aplicado.")
end

local window = make("Frame", {
    Name = "Window",
    Size = U(0, 690, 0, 430),
    Position = U(0.5, -345, 0.5, -215),
    BackgroundColor3 = colors.bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
}, gui)
make("UICorner", { CornerRadius = D(0, 8) }, window)
make("UIStroke", { Color = colors.stroke, Transparency = 0.15, Thickness = 1 }, window)

local titleBar = make("Frame", {
    Size = U(1, 0, 0, 38),
    BackgroundColor3 = C(24, 21, 27),
    BorderSizePixel = 0,
}, window)

make("TextLabel", {
    Size = U(1, -90, 1, 0),
    Position = U(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = HUB,
    TextColor3 = colors.accent2,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
}, titleBar)

make("TextLabel", {
    Size = U(0, 270, 1, 0),
    Position = U(0, 112, 0, 1),
    BackgroundTransparency = 1,
    Text = "YARHM modules, Ayia UI",
    TextColor3 = colors.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 12,
}, titleBar)

local close = make("TextButton", {
    Size = U(0, 34, 0, 26),
    Position = U(1, -42, 0, 6),
    BackgroundTransparency = 1,
    Text = "x",
    TextColor3 = colors.muted,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    AutoButtonColor = false,
}, titleBar)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local sidebar = make("Frame", {
    Size = U(0, 148, 1, -38),
    Position = U(0, 0, 0, 38),
    BackgroundColor3 = C(18, 16, 21),
    BorderSizePixel = 0,
}, window)
make("UIPadding", {
    PaddingTop = D(0, 12),
    PaddingLeft = D(0, 8),
    PaddingRight = D(0, 8),
}, sidebar)
make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = D(0, 6),
}, sidebar)

local content = make("Frame", {
    Size = U(1, -148, 1, -38),
    Position = U(0, 148, 0, 38),
    BackgroundColor3 = colors.panel,
    BorderSizePixel = 0,
}, window)

local tabs = {}
local activeTab

local function selectTab(name)
    activeTab = name

    for tabName, tab in pairs(tabs) do
        local active = tabName == name
        tab.Page.Visible = active
        tab.Button.BackgroundColor3 = active and colors.accent or colors.panel2
        tab.Button.TextColor3 = active and colors.text or colors.muted
    end
end

local function createTab(name, order)
    local button = make("TextButton", {
        LayoutOrder = order,
        Size = U(1, 0, 0, 36),
        BackgroundColor3 = colors.panel2,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = colors.muted,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        AutoButtonColor = false,
    }, sidebar)
    make("UICorner", { CornerRadius = D(0, 7) }, button)

    local page = make("ScrollingFrame", {
        Name = name,
        Size = U(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = colors.accent,
        Visible = false,
        CanvasSize = U(0, 0, 0, 0),
    }, content)

    make("UIPadding", {
        PaddingTop = D(0, 16),
        PaddingBottom = D(0, 16),
        PaddingLeft = D(0, 18),
        PaddingRight = D(0, 18),
    }, page)

    local layout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = D(0, 8),
    }, page)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = U(0, 0, 0, layout.AbsoluteContentSize.Y + 34)
    end)

    button.MouseButton1Click:Connect(function()
        selectTab(name)
    end)

    tabs[name] = {
        Button = button,
        Page = page,
        Layout = layout,
    }
end

local function addSection(tabName, title)
    make("TextLabel", {
        Size = U(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 17,
    }, tabs[tabName].Page)
end

local function addNote(tabName, text)
    make("TextLabel", {
        Size = U(1, 0, 0, 34),
        BackgroundTransparency = 1,
        RichText = true,
        Text = text,
        TextColor3 = colors.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 12,
    }, tabs[tabName].Page)
end

local function addButton(tabName, label, callback)
    local button = make("TextButton", {
        Size = U(1, 0, 0, 36),
        BackgroundColor3 = colors.panel2,
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        AutoButtonColor = false,
    }, tabs[tabName].Page)
    make("UICorner", { CornerRadius = D(0, 7) }, button)
    make("UIPadding", {
        PaddingLeft = D(0, 12),
        PaddingRight = D(0, 12),
    }, button)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = C(43, 35, 47)
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = colors.panel2
    end)

    button.MouseButton1Click:Connect(function()
        safeRun(callback)
    end)
end

local function addToggle(tabName, label, default, callback)
    local value = default == true
    local row = make("Frame", {
        Size = U(1, 0, 0, 38),
        BackgroundColor3 = colors.panel2,
        BorderSizePixel = 0,
    }, tabs[tabName].Page)
    make("UICorner", { CornerRadius = D(0, 7) }, row)

    make("TextLabel", {
        Size = U(1, -70, 1, 0),
        Position = U(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
    }, row)

    local switch = make("Frame", {
        Size = U(0, 42, 0, 20),
        Position = U(1, -54, 0.5, -10),
        BackgroundColor3 = colors.bg,
        BorderSizePixel = 0,
    }, row)
    make("UICorner", { CornerRadius = D(1, 0) }, switch)

    local knob = make("Frame", {
        Size = U(0, 16, 0, 16),
        Position = U(0, 2, 0, 2),
        BackgroundColor3 = colors.muted,
        BorderSizePixel = 0,
    }, switch)
    make("UICorner", { CornerRadius = D(1, 0) }, knob)

    local hit = make("TextButton", {
        Size = U(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local function paint()
        switch.BackgroundColor3 = value and colors.accent or colors.bg
        knob.BackgroundColor3 = value and colors.text or colors.muted
        knob.Position = value and U(1, -18, 0, 2) or U(0, 2, 0, 2)
    end

    hit.MouseButton1Click:Connect(function()
        value = not value
        paint()
        safeRun(callback, value)
    end)

    paint()

    if default then
        safeRun(callback, value)
    end
end

local function addInput(tabName, label, buttonText, defaultText, callback)
    local row = make("Frame", {
        Size = U(1, 0, 0, 42),
        BackgroundColor3 = colors.panel2,
        BorderSizePixel = 0,
    }, tabs[tabName].Page)
    make("UICorner", { CornerRadius = D(0, 7) }, row)

    make("TextLabel", {
        Size = U(1, -178, 1, 0),
        Position = U(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
    }, row)

    local box = make("TextBox", {
        Size = U(0, 76, 0, 26),
        Position = U(1, -156, 0.5, -13),
        BackgroundColor3 = colors.bg,
        BorderSizePixel = 0,
        Text = tostring(defaultText or ""),
        TextColor3 = colors.text,
        PlaceholderText = "...",
        PlaceholderColor3 = colors.muted,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
    }, row)
    make("UICorner", { CornerRadius = D(0, 6) }, box)

    local button = make("TextButton", {
        Size = U(0, 66, 0, 26),
        Position = U(1, -74, 0.5, -13),
        BackgroundColor3 = colors.accent,
        BorderSizePixel = 0,
        Text = buttonText or "Set",
        TextColor3 = colors.text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    }, row)
    make("UICorner", { CornerRadius = D(0, 6) }, button)

    button.MouseButton1Click:Connect(function()
        safeRun(callback, box.Text)
    end)
end

createTab("Visuals", 1)
createTab("Combat", 2)
createTab("Player", 3)
createTab("Teleports", 4)
createTab("Utility", 5)
createTab("Settings", 6)

addSection("Visuals", "ESPs")
addToggle("Visuals", "Players ESP", false, function(value)
    state.playerESP = value
    reloadPlayerESP()
end)
addToggle("Visuals", "Dropped gun ESP", false, function(value)
    state.gunESP = value
    reloadGunESP()
end)
addToggle("Visuals", "Traps ESP", false, function(value)
    state.trapESP = value
    reloadTrapESP()
end)
addToggle("Visuals", "Hide my own ESP", false, function(value)
    state.hideOwnESP = value
    reloadPlayerESP()
end)
addButton("Visuals", "Reload ESP", function()
    reloadPlayerESP()
    reloadGunESP()
    reloadTrapESP()
    notify("ESP recarregado.")
end)
addToggle("Visuals", "Round timer", false, setRoundTimer)

addSection("Combat", "Sheriff")
addButton("Combat", "Shoot murderer", shootMurderer)
addButton("Combat", "Delayed shoot murderer", delayedShootMurderer)
addToggle("Combat", "Instakill murderer as sheriff", false, function(value)
    state.instakillShoot = value
end)
addInput("Combat", "Shoot position offset", "Set", state.shootOffset, function(text)
    local value = tonumber(text)

    if not value then
        notify("Numero invalido.")
        return
    end

    state.shootOffset = value
    notify("Offset atualizado.")
end)
addInput("Combat", "Offset-to-ping multiplier", "Set", state.offsetToPingMult, function(text)
    local value = tonumber(text)

    if not value then
        notify("Numero invalido.")
        return
    end

    state.offsetToPingMult = value
    notify("Ping multiplier atualizado.")
end)

addSection("Combat", "Murderer")
addButton("Combat", "Knife throw to closest", function()
    knifeThrow(false)
end)
addToggle("Combat", "Auto knife throw", false, function(value)
    state.autoKnifeThrow = value
end)
addToggle("Combat", "Spawn knife throw near player", false, function(value)
    state.spawnKnifeNearPlayer = value
end)
addButton("Combat", "Kill closest player as murderer", killClosest)
addToggle("Combat", "Murderer kill aura", false, setKillAura)
addButton("Combat", "Kill everyone as murderer", killEveryone)
addButton("Combat", "Hold everyone hostage", holdEveryone)

addSection("Player", "Movement")
addToggle("Player", "OP Fly", false, setFly)
addInput("Player", "Fly speed", "Set", state.flySpeed, function(text)
    local value = tonumber(text)

    if value then
        state.flySpeed = value
        notify("Fly speed atualizado.")
    else
        notify("Numero invalido.")
    end
end)
addToggle("Player", "Infinite jump", false, setInfiniteJump)
addInput("Player", "Walkspeed", "Set", state.walkSpeed, function(text)
    local value = tonumber(text)

    if value then
        state.walkSpeed = value
        applyWalkSpeed()
    else
        notify("Numero invalido.")
    end
end)
addToggle("Player", "Loop walkspeed", false, function(value)
    state.loopWalkSpeed = value
end)
addInput("Player", "Jump power", "Set", state.jumpPower, function(text)
    local value = tonumber(text)

    if value then
        state.jumpPower = value
        applyJumpPower()
    else
        notify("Numero invalido.")
    end
end)
addInput("Player", "FOV change", "Set", state.fov, function(text)
    local value = tonumber(text)

    if value then
        state.fov = value
        workspace.CurrentCamera.FieldOfView = value
    else
        notify("Numero invalido.")
    end
end)
addToggle("Player", "Loop FOV", false, function(value)
    state.loopFov = value
end)

addSection("Player", "Hitbox")
addToggle("Player", "Hitbox expander", false, setHitboxExpander)
addToggle("Player", "Loop hitbox expansion", false, function(value)
    state.loopHitbox = value
end)
addInput("Player", "Hitbox size", "Set", state.hitboxSize, function(text)
    local value = tonumber(text)

    if value then
        state.hitboxSize = value

        if state.hitboxExpander then
            applyHitboxes()
        end
    else
        notify("Numero invalido.")
    end
end)

addSection("Teleports", "Places")
addToggle("Teleports", "CTRL+Click Teleport", false, setCtrlClickTeleport)
addButton("Teleports", "Teleport to lobby", teleportLobby)
addButton("Teleports", "Teleport to map", teleportMap)
addButton("Teleports", "Teleport to dropped gun", teleportDroppedGun)
addToggle("Teleports", "Automatically get gun on drop", false, function(value)
    state.autoGetGun = value
end)

addSection("Utility", "Roles")
addButton("Utility", "Send Sheriff and Murderer names into chat", sendRolesToChat)
addButton("Utility", "Copy murderer username", function()
    copyName(findMurderer(), "murderer")
end)
addButton("Utility", "Copy sheriff username", function()
    copyName(findSheriff(), "sheriff")
end)

addSection("Utility", "Tools")
addToggle("Utility", "Ignore knife throws", false, function(value)
    state.ignoreKnifeThrows = value
end)
addButton("Utility", "God mode", godMode)
addButton("Utility", "Anti AFK detection", antiAfk)
addButton("Utility", "FPS Boost", fpsBoost)

addSection("Settings", "Ayia")
addNote("Settings", "O Hub usa os modulos/opcoes do YARHM com a GUI propria do Ayia Hub. Nao carrega a interface original do YARHM.")
addButton("Settings", "Reload roles", function()
    reloadPlayerESP()
    notify("Roles recarregados.")
end)
addButton("Settings", "Close Ayia Hub", function()
    gui:Destroy()
end)

selectTab("Visuals")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")
local playerDataChanged = gameplay and gameplay:FindFirstChild("PlayerDataChanged")

if playerDataChanged then
    connections.playerData = playerDataChanged.OnClientEvent:Connect(function(data)
        playerData = data or {}
        reloadPlayerESP()
    end)
end

connections.workspaceAdded = workspace.DescendantAdded:Connect(function(object)
    if object.Name == "GunDrop" then
        if state.gunESP then
            task.wait(0.1)
            reloadGunESP()
            notify("Gun dropada.")
        end

        if state.autoGetGun then
            task.wait(1)
            teleportDroppedGun()
        end
    elseif object:IsA("BasePart") and object.Name == "Trap" and state.trapESP then
        object.Transparency = 0
        addESP("traps", object, colors.danger, "Trap")
        notify("Trap detectada.")
    elseif object.Name == "ThrowingKnife" and state.ignoreKnifeThrows then
        object:Destroy()
    end
end)

connections.workspaceRemoving = workspace.DescendantRemoving:Connect(function(object)
    if object.Name == "GunDrop" and state.gunESP then
        task.defer(reloadGunESP)
    end
end)

connections.playerAdded = Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        reloadPlayerESP()
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        task.wait(1)
        reloadPlayerESP()
    end)
end

connections.heartbeat = RunService.Heartbeat:Connect(function()
    if state.loopWalkSpeed then
        applyWalkSpeed()
    end

    if state.loopFov and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = state.fov
    end

    if state.loopHitbox and state.hitboxExpander then
        applyHitboxes()
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(1.5)

        if state.autoKnifeThrow then
            safeRun(knifeThrow, true)
        end
    end
end)

gui.Destroying:Connect(function()
    for name in pairs(connections) do
        disconnect(name)
    end

    clearESP("players")
    clearESP("gun")
    clearESP("traps")
    restoreHitboxes()
    setFly(false)
end)

notify("Ayia Hub carregado.")
