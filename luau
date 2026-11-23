--// PURPLE FLIPS - Backflip & Frontflip with keybinds you set in the GUI
--// Standalone LocalScript. Drag the window ONLY by its title bar.
--// Click a key box, then press any key to bind it.
--// Esc = cancel, Backspace = no key.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (type(getgenv) == "function" and getgenv()) or _G
local key = "PurpleFlipsCore"
local SAVE_FILE = "PurpleFlipsBinds.json"

if env[key] and type(env[key].Unload) == "function" then
    env[key].Unload()
end
local old = playerGui:FindFirstChild("PurpleFlips")
if old then old:Destroy() end

local core = {Connections = {}, Running = true, Flipping = false}
env[key] = core

-- Flip feel
local FLIP_POWER = 55   -- how high you jump for a flip
local DRIFT = 10        -- how far you move forward/back during the flip

local colors = {
    bg = Color3.fromRGB(35, 20, 55),
    panel = Color3.fromRGB(65, 35, 95),
    accent = Color3.fromRGB(170, 75, 255),
    glow = Color3.fromRGB(210, 140, 255),
    text = Color3.fromRGB(220, 170, 255),
    white = Color3.fromRGB(255, 255, 255)
}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(core.Connections, connection)
    return connection
end

local function tween(obj, time, props)
    local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

----------------------------------------------------------------------
-- KEYBINDS (saved so they stay after you re-run the script)
----------------------------------------------------------------------
local binds = {Backflip = Enum.KeyCode.Z, Frontflip = Enum.KeyCode.X}

local function loadBinds()
    local data = env.PurpleFlipsBinds
    if not data and type(readfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(SAVE_FILE) then data = HttpService:JSONDecode(readfile(SAVE_FILE)) end
        end)
    end
    if type(data) ~= "table" then return end
    for name in pairs(binds) do
        local v = data[name]
        if v == "None" then
            binds[name] = nil
        elseif type(v) == "string" and Enum.KeyCode[v] then
            binds[name] = Enum.KeyCode[v]
        end
    end
end

local function saveBinds()
    local data = {}
    for _, name in ipairs({"Backflip", "Frontflip"}) do
        data[name] = binds[name] and binds[name].Name or "None"
    end
    env.PurpleFlipsBinds = data
    if type(writefile) == "function" then
        pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(data)) end)
    end
end

loadBinds()

----------------------------------------------------------------------
-- FLIPS
----------------------------------------------------------------------
local function flip(name)
    if core.Flipping or not core.Running then return end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    if hum.Sit then return end
    core.Flipping = true

    local front = (name == "Frontflip")
    local look = root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
    local facing = CFrame.lookAt(Vector3.zero, flat) -- rotation only

    -- Jump if on the ground (in the air it just flips).
    local airtime = 0.45
    if hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            + Vector3.yAxis * FLIP_POWER
            + flat * (front and DRIFT or -DRIFT)
        airtime = 2 * FLIP_POWER / workspace.Gravity
    end
    local duration = math.clamp(airtime * 0.9, 0.35, 0.9)

    local autoRotate = hum.AutoRotate
    hum.AutoRotate = false

    -- Purple swoosh trail while flipping.
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 1.3, 0)
    a0.Parent = root
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -1.3, 0)
    a1.Parent = root
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = 0.3
    trail.LightEmission = 1
    trail.FaceCamera = true
    trail.Color = ColorSequence.new(colors.glow, colors.accent)
    trail.Transparency = NumberSequence.new(0.25, 1)
    trail.Parent = root

    -- Spin: smooth start and finish, one full 360.
    local start = os.clock()
    while core.Running and root.Parent and hum.Health > 0 do
        RunService.Heartbeat:Wait()
        local a = math.min((os.clock() - start) / duration, 1)
        local eased = (1 - math.cos(math.pi * a)) / 2
        local angle = eased * math.pi * 2 * (front and -1 or 1)
        root.CFrame = CFrame.new(root.Position) * facing * CFrame.Angles(angle, 0, 0)
        root.AssemblyAngularVelocity = Vector3.zero
        if a >= 1 then break end
    end

    -- Land upright.
    if root.Parent then
        root.CFrame = CFrame.new(root.Position) * facing
        root.AssemblyAngularVelocity = Vector3.zero
    end
    hum.AutoRotate = autoRotate
    trail.Enabled = false
    task.delay(0.35, function()
        trail:Destroy()
        a0:Destroy()
        a1:Destroy()
    end)
    core.Flipping = false
end

----------------------------------------------------------------------
-- GUI
----------------------------------------------------------------------
local function round(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = obj
end

local function button(text, position, size, parent)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Position = position
    b.Size = size
    b.BackgroundColor3 = colors.panel
    b.BorderSizePixel = 0
    b.TextColor3 = colors.white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.AutoButtonColor = false
    b.Parent = parent
    round(b, 8)
    return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "PurpleFlips"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local FULL_HEIGHT = 196
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, FULL_HEIGHT)
frame.Position = UDim2.new(1, -310, 0.5, -98)
frame.BackgroundColor3 = colors.bg
frame.BorderSizePixel = 0
frame.Active = true
frame.ClipsDescendants = true
frame.Parent = gui
round(frame, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = colors.accent
stroke.Thickness = 2
stroke.Parent = frame

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, -76, 0, 40)
topBar.BackgroundTransparency = 1
topBar.Active = true
topBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -14, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "FLIPS"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = colors.text
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.Parent = topBar

local minimize = button("−", UDim2.new(1, -72, 0, 6), UDim2.fromOffset(30, 28), frame)
local close = button("X", UDim2.new(1, -38, 0, 6), UDim2.fromOffset(30, 28), frame)

local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(0, 42)
content.Size = UDim2.new(1, 0, 1, -42)
content.BackgroundTransparency = 1
content.Parent = frame

local headerAction = Instance.new("TextLabel")
headerAction.Size = UDim2.fromOffset(140, 16)
headerAction.Position = UDim2.fromOffset(16, 0)
headerAction.BackgroundTransparency = 1
headerAction.Text = "TAP TO FLIP"
headerAction.TextXAlignment = Enum.TextXAlignment.Left
headerAction.TextColor3 = colors.text
headerAction.Font = Enum.Font.GothamBold
headerAction.TextSize = 11
headerAction.Parent = content

local headerKey = headerAction:Clone()
headerKey.Position = UDim2.fromOffset(166, 0)
headerKey.Text = "KEYBIND"
headerKey.Parent = content

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -24, 0, 30)
hint.Position = UDim2.fromOffset(12, 118)
hint.BackgroundTransparency = 1
hint.Text = "Click a key box, then press a key.\nEsc = cancel · Backspace = none"
hint.TextColor3 = colors.text
hint.TextTransparency = 0.25
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.Parent = content

local rows = {}
local bindingName = nil

local function refreshKeys()
    for name, row in pairs(rows) do
        if bindingName == name then
            row.key.Text = "Press a key..."
            tween(row.key, 0.15, {BackgroundColor3 = colors.accent})
        else
            row.key.Text = binds[name] and binds[name].Name or "None"
            tween(row.key, 0.15, {BackgroundColor3 = colors.panel})
        end
    end
end

for index, name in ipairs({"Backflip", "Frontflip"}) do
    local y = 20 + (index - 1) * 48
    local action = button(string.upper(name), UDim2.fromOffset(16, y), UDim2.fromOffset(140, 40), content)
    local keyBtn = button("", UDim2.fromOffset(166, y), UDim2.fromOffset(98, 40), content)
    keyBtn.TextSize = 14
    rows[name] = {action = action, key = keyBtn}

    connect(action.MouseButton1Click, function()
        task.spawn(flip, name)
    end)
    connect(action.MouseEnter, function() tween(action, 0.15, {BackgroundColor3 = colors.accent}) end)
    connect(action.MouseLeave, function() tween(action, 0.15, {BackgroundColor3 = colors.panel}) end)

    connect(keyBtn.MouseButton1Click, function()
        bindingName = (bindingName == name) and nil or name
        refreshKeys()
    end)
end
refreshKeys()

-- Keyboard: set binds, or do flips.
connect(UIS.InputBegan, function(input, processed)
    if bindingName then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local kc = input.KeyCode
            if kc == Enum.KeyCode.Escape then
                -- cancel, keep old key
            elseif kc == Enum.KeyCode.Backspace then
                binds[bindingName] = nil
            else
                for other, otherKey in pairs(binds) do
                    if other ~= bindingName and otherKey == kc then
                        binds[other] = nil -- one key can't do both flips
                    end
                end
                binds[bindingName] = kc
            end
            bindingName = nil
            saveBinds()
            refreshKeys()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
            bindingName = nil -- clicked away
            refreshKeys()
        end
        return
    end

    if processed then return end -- typing in chat etc.
    for name, kc in pairs(binds) do
        if input.KeyCode == kc then
            task.spawn(flip, name)
        end
    end
end)

-- Minimize
local minimized = false
connect(minimize.MouseButton1Click, function()
    minimized = not minimized
    content.Visible = not minimized
    tween(frame, 0.2, {Size = UDim2.fromOffset(280, minimized and 40 or FULL_HEIGHT)})
    minimize.Text = minimized and "+" or "−"
end)

-- Title-bar dragging.
local dragMouse, dragTouch, dragStart, frameStart = false, nil, nil, nil
connect(topBar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragMouse = true
    elseif input.UserInputType == Enum.UserInputType.Touch then
        dragTouch = input
    else
        return
    end
    dragStart = input.Position
    frameStart = frame.Position
end)
connect(UIS.InputChanged, function(input)
    if not ((dragMouse and input.UserInputType == Enum.UserInputType.MouseMovement)
        or (dragTouch and input == dragTouch)) then return end
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        frameStart.X.Scale, frameStart.X.Offset + delta.X,
        frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
    )
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragMouse = false end
    if input == dragTouch then dragTouch = nil end
end)

----------------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------------
function core.Unload()
    if not core.Running then return end
    core.Running = false
    for _, connection in ipairs(core.Connections) do
        connection:Disconnect()
    end
    if gui then gui:Destroy() end
    if env[key] == core then env[key] = nil end
end

connect(close.MouseButton1Click, function()
    core.Unload()
end)
