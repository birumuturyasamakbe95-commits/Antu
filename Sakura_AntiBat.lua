-- ============================================================
-- Sakura.vs Anti Bat — STANDALONE (execute = panel açılır)
-- ============================================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer

local _V3new = Vector3.new
local _V3zero = Vector3.zero

-- Eski paneli temizle
pcall(function()
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("SakuraAntiBat")
        if g then g:Destroy() end
    end
    local cg = game:GetService("CoreGui")
    local g2 = cg:FindFirstChild("SakuraAntiBat")
    if g2 then g2:Destroy() end
end)

-- State
local antiBatEnabled = false
local antiBatConn = nil
local antiBatPanelGui = nil
local antiBatPanelVisible = false
local antiBatPanelPos = nil
local antiBatPanelCollapsed = false
local BACKGROUND_ASSET_ID = "126567400601699"

-- Panel visual updaters (keybind'lerden erişmek için)
local setToggleVisualRef = nil
local setInfJumpVisualRef = nil

-- ============================================================
-- Anti Bat logic
-- ============================================================
local _antiBatSpeed = 80000
local _antiBatAngle = 0
local _antiBatDirection = 1

local function stopAntiBat()
    antiBatEnabled = false
    if antiBatConn then
        pcall(function() antiBatConn:Disconnect() end)
        antiBatConn = nil
    end
    _antiBatSpeed = 80000
    _antiBatAngle = 0
    _antiBatDirection = 1
end

local function startAntiBat()
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    antiBatEnabled = true
    if antiBatConn then
        pcall(function() antiBatConn:Disconnect() end)
        antiBatConn = nil
    end

    antiBatConn = RunService.Heartbeat:Connect(function()
        if not antiBatEnabled then return end
        local c = LP.Character
        if not c then return end
        root = c:FindFirstChild("HumanoidRootPart")
        if not root or not root.Parent then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then return end

        local origXZ = _V3new(root.Velocity.X, 0, root.Velocity.Z)

        _antiBatSpeed = _antiBatSpeed + (400 * _antiBatDirection)
        if _antiBatSpeed >= 250000 then
            _antiBatSpeed = 250000
            _antiBatDirection = -1
        elseif _antiBatSpeed <= 80000 then
            _antiBatSpeed = 80000
            _antiBatDirection = 1
        end

        _antiBatAngle = _antiBatAngle + (math.random() * 1.8)

        local radius = _antiBatSpeed + math.random(-40000, 40000)
        local newX = math.cos(_antiBatAngle) * radius
        local newZ = math.sin(_antiBatAngle) * radius

        root.Velocity = _V3new(newX, root.Velocity.Y, newZ)

        RunService.RenderStepped:Wait()

        if root and root.Parent then
            root.Velocity = _V3new(origXZ.X, root.Velocity.Y, origXZ.Z)
        end
    end)
end

local function setAntiBat(on)
    if on then startAntiBat() else stopAntiBat() end
end

-- ============================================================
-- Hold Jump (Clean Hub tarzı)
-- ============================================================
local infJumpEnabled = false
local infJumpMode = "HOLD" -- HOLD: basılı tutunca sürekli | MANUAL: sadece JumpRequest

local HoldJumpState = {
    holdPressed = false,
    holdActive = false,
    controllerActive = false,
    mobilePressed = false,
    mobileActive = false,
    hooked = {},
}

local function applyInfJumpBoost(boost)
    if not infJumpEnabled then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local curVel = hrp.Velocity
    hrp.Velocity = _V3new(curVel.X, boost or 50, curVel.Z)
end

local function stopInfJumpHoldState()
    HoldJumpState.holdPressed = false
    HoldJumpState.holdActive = false
    HoldJumpState.controllerActive = false
    HoldJumpState.mobilePressed = false
    HoldJumpState.mobileActive = false
end

local function stopInfJump()
    infJumpEnabled = false
    stopInfJumpHoldState()
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function() hrp.Velocity = _V3zero end)
    end
end

local function startInfJump()
    infJumpEnabled = true
end

local function setInfJump(on)
    if on then startInfJump() else stopInfJump() end
end

-- JumpRequest → tek basışta boost (MANUAL + HOLD)
UIS.JumpRequest:Connect(function()
    applyInfJumpBoost(50)
end)

-- Space / Gamepad hold
UIS.InputBegan:Connect(function(input)
    if UIS:GetFocusedTextBox() then return end
    local S = HoldJumpState

    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Enum.KeyCode.Space then
        if infJumpMode == "MANUAL" then return end
        S.holdPressed = true
        task.delay(0.12, function()
            if HoldJumpState.holdPressed and infJumpEnabled then
                HoldJumpState.holdActive = true
                applyInfJumpBoost(50)
            end
        end)
    elseif input.KeyCode == Enum.KeyCode.ButtonA
       and tostring(input.UserInputType):match("Gamepad") then
        if infJumpMode ~= "MANUAL" then
            S.controllerActive = true
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    local S = HoldJumpState
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Enum.KeyCode.Space then
        S.holdPressed = false
        S.holdActive = false
    end
    if input.KeyCode == Enum.KeyCode.ButtonA
       and tostring(input.UserInputType):match("Gamepad") then
        S.controllerActive = false
    end
end)

-- Mobil JumpButton hook
local function hookMobileJumpButton(obj)
    local S = HoldJumpState
    if not obj or obj.Name ~= "JumpButton"
       or not obj:IsA("GuiButton") or S.hooked[obj] then
        return
    end
    S.hooked[obj] = true
    obj.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
           or not infJumpEnabled then
            return
        end
        if infJumpMode == "MANUAL" then return end
        S.mobilePressed = true
        task.delay(0.12, function()
            if S.mobilePressed and infJumpEnabled then
                S.mobileActive = true
                applyInfJumpBoost(50)
            end
        end)
    end)
    obj.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            S.mobilePressed = false
            S.mobileActive = false
        end
    end)
end

do
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            hookMobileJumpButton(obj)
        end
        pg.DescendantAdded:Connect(function(obj)
            task.defer(hookMobileJumpButton, obj)
        end)
    end
end

-- HOLD modunda basılı tutunca sürekli boost
RunService.Heartbeat:Connect(function()
    local S = HoldJumpState
    if infJumpEnabled and infJumpMode == "HOLD"
       and (S.holdActive or S.mobileActive or S.controllerActive) then
        applyInfJumpBoost(50)
    end
end)

-- ============================================================
-- Panel
-- ============================================================
local function destroyAntiBatPanel()
    if antiBatPanelGui then
        pcall(function() antiBatPanelGui:Destroy() end)
        antiBatPanelGui = nil
    end
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            local g = pg:FindFirstChild("SakuraAntiBat")
            if g then g:Destroy() end
        end
        local cg = game:GetService("CoreGui")
        local g2 = cg:FindFirstChild("SakuraAntiBat")
        if g2 then g2:Destroy() end
    end)
    antiBatPanelVisible = false
    setToggleVisualRef = nil
    setInfJumpVisualRef = nil
end

local function createAntiBatPanel()
    destroyAntiBatPanel()
    local BLUE = Color3.fromRGB(255, 255, 255)
    local WHITE = Color3.fromRGB(255, 255, 255)
    local FULL_H = 212
    local MINI_H = 44
    local collapsed = antiBatPanelCollapsed == true

    local gui = Instance.new("ScreenGui")
    gui.Name = "SakuraAntiBat"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
    local okP = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not okP then
        gui.Parent = LP:WaitForChild("PlayerGui")
    end

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.ClipsDescendants = true
    if antiBatPanelPos and type(antiBatPanelPos.XOffset) == "number" then
        Main.Position = UDim2.new(
            antiBatPanelPos.XScale or 0,
            antiBatPanelPos.XOffset or 0,
            antiBatPanelPos.YScale or 0,
            antiBatPanelPos.YOffset or 0
        )
    else
        Main.Position = UDim2.new(0.5, -130, 0.5, -106)
    end
    Main.Size = UDim2.new(0, 260, 0, collapsed and MINI_H or FULL_H)
    Main.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Parent = gui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", Main)
    stroke.Color = BLUE
    stroke.Thickness = 1.4
    stroke.Transparency = 0.25

    local bg = Instance.new("ImageLabel", Main)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundTransparency = 1
    bg.Image = "rbxthumb://type=Asset&id=" .. tostring(BACKGROUND_ASSET_ID) .. "&w=768&h=432"
    bg.ImageTransparency = 0.12
    bg.ScaleType = Enum.ScaleType.Crop
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

    local dim = Instance.new("Frame", Main)
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.45
    dim.BorderSizePixel = 0
    dim.ZIndex = 2
    Instance.new("UICorner", dim).CornerRadius = UDim.new(0, 14)

    local titleBar = Instance.new("Frame", Main)
    titleBar.Name = "TitleBar"
    titleBar.ZIndex = 5
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundTransparency = 1
    titleBar.Active = true

    local title = Instance.new("TextLabel", titleBar)
    title.ZIndex = 5
    title.Position = UDim2.new(0, 14, 0, 4)
    title.Size = UDim2.new(1, -90, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "discord.gg/sakuraduels"
    title.TextColor3 = BLUE
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left

    local minBtn = Instance.new("TextButton", titleBar)
    minBtn.Name = "Minimize"
    minBtn.ZIndex = 7
    minBtn.Position = UDim2.new(1, -64, 0, 9)
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    minBtn.Text = collapsed and "□" or "_"
    minBtn.TextColor3 = WHITE
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.AutoButtonColor = false
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.ZIndex = 7
    closeBtn.Position = UDim2.new(1, -34, 0, 9)
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    closeBtn.Text = "×"
    closeBtn.TextColor3 = WHITE
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.AutoButtonColor = false
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local content = Instance.new("Frame", Main)
    content.Name = "Content"
    content.ZIndex = 5
    content.Position = UDim2.new(0, 0, 0, 44)
    content.Size = UDim2.new(1, 0, 1, -44)
    content.BackgroundTransparency = 1
    content.Visible = not collapsed

    local line = Instance.new("Frame", content)
    line.ZIndex = 5
    line.Position = UDim2.new(0, 14, 0, 0)
    line.Size = UDim2.new(1, -28, 0, 1)
    line.BackgroundColor3 = BLUE
    line.BackgroundTransparency = 0.5
    line.BorderSizePixel = 0

    -- Anti Bat row
    local row = Instance.new("Frame", content)
    row.ZIndex = 5
    row.Position = UDim2.new(0, 14, 0, 12)
    row.Size = UDim2.new(1, -28, 0, 44)
    row.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
    row.BackgroundTransparency = 0.25
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = Color3.fromRGB(80, 80, 80)
    rowStroke.Transparency = 0.4

    local lbl = Instance.new("TextLabel", row)
    lbl.ZIndex = 6
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(1, -90, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Anti Bat"
    lbl.TextColor3 = WHITE
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Name = "Track"
    track.ZIndex = 7
    track.Position = UDim2.new(1, -58, 0.5, -12)
    track.Size = UDim2.new(0, 46, 0, 24)
    track.BackgroundColor3 = antiBatEnabled and BLUE or Color3.fromRGB(55, 55, 68)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", track)
    knob.Name = "Knob"
    knob.ZIndex = 8
    knob.Position = antiBatEnabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local toggleBtn = Instance.new("TextButton", track)
    toggleBtn.ZIndex = 9
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ""

    -- Hold Jump row
    local row2 = Instance.new("Frame", content)
    row2.ZIndex = 5
    row2.Position = UDim2.new(0, 14, 0, 64)
    row2.Size = UDim2.new(1, -28, 0, 44)
    row2.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
    row2.BackgroundTransparency = 0.25
    row2.BorderSizePixel = 0
    Instance.new("UICorner", row2).CornerRadius = UDim.new(0, 10)
    local row2Stroke = Instance.new("UIStroke", row2)
    row2Stroke.Color = Color3.fromRGB(80, 80, 80)
    row2Stroke.Transparency = 0.4

    local lbl2 = Instance.new("TextLabel", row2)
    lbl2.ZIndex = 6
    lbl2.Position = UDim2.new(0, 12, 0, 0)
    lbl2.Size = UDim2.new(1, -90, 1, 0)
    lbl2.BackgroundTransparency = 1
    lbl2.Text = "Hold Jump  [J]"
    lbl2.TextColor3 = WHITE
    lbl2.Font = Enum.Font.GothamMedium
    lbl2.TextSize = 13
    lbl2.TextXAlignment = Enum.TextXAlignment.Left

    local track2 = Instance.new("Frame", row2)
    track2.Name = "Track"
    track2.ZIndex = 7
    track2.Position = UDim2.new(1, -58, 0.5, -12)
    track2.Size = UDim2.new(0, 46, 0, 24)
    track2.BackgroundColor3 = infJumpEnabled and BLUE or Color3.fromRGB(55, 55, 68)
    track2.BorderSizePixel = 0
    Instance.new("UICorner", track2).CornerRadius = UDim.new(1, 0)

    local knob2 = Instance.new("Frame", track2)
    knob2.Name = "Knob"
    knob2.ZIndex = 8
    knob2.Position = infJumpEnabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob2.Size = UDim2.new(0, 18, 0, 18)
    knob2.BackgroundColor3 = WHITE
    knob2.BorderSizePixel = 0
    Instance.new("UICorner", knob2).CornerRadius = UDim.new(1, 0)

    local toggleBtn2 = Instance.new("TextButton", track2)
    toggleBtn2.ZIndex = 9
    toggleBtn2.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn2.BackgroundTransparency = 1
    toggleBtn2.Text = ""

    local footer = Instance.new("TextLabel", content)
    footer.ZIndex = 6
    footer.Position = UDim2.new(0, 0, 0, 118)
    footer.Size = UDim2.new(1, 0, 0, 18)
    footer.BackgroundTransparency = 1
    footer.Text = "discord.gg/sakuraduels"
    footer.TextColor3 = BLUE
    footer.Font = Enum.Font.GothamBold
    footer.TextSize = 11

    local function setToggleVisual(on)
        TS:Create(track, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundColor3 = on and BLUE or Color3.fromRGB(55, 55, 68)
        }):Play()
        TS:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
    end

    local function setInfJumpVisual(on)
        TS:Create(track2, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundColor3 = on and BLUE or Color3.fromRGB(55, 55, 68)
        }):Play()
        TS:Create(knob2, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
    end

    setToggleVisualRef = setToggleVisual
    setInfJumpVisualRef = setInfJumpVisual

    local function setCollapsed(on)
        collapsed = on and true or false
        antiBatPanelCollapsed = collapsed
        content.Visible = not collapsed
        Main.Size = UDim2.new(0, 260, 0, collapsed and MINI_H or FULL_H)
        minBtn.Text = collapsed and "□" or "_"
    end

    toggleBtn.MouseButton1Click:Connect(function()
        setAntiBat(not antiBatEnabled)
        setToggleVisual(antiBatEnabled)
    end)

    toggleBtn2.MouseButton1Click:Connect(function()
        setInfJump(not infJumpEnabled)
        setInfJumpVisual(infJumpEnabled)
    end)

    minBtn.MouseButton1Click:Connect(function()
        setCollapsed(not collapsed)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        destroyAntiBatPanel()
        stopAntiBat()
        stopInfJump()
    end)

    -- Drag
    do
        local dragging, dragStart, startPos, activeInput = false, nil, nil, nil
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Main.Position
                activeInput = input
            end
        end)
        titleBar.InputEnded:Connect(function(input)
            if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
                if dragging then
                    antiBatPanelPos = {
                        XScale = Main.Position.X.Scale,
                        XOffset = Main.Position.X.Offset,
                        YScale = Main.Position.Y.Scale,
                        YOffset = Main.Position.Y.Offset,
                    }
                end
                dragging = false
                activeInput = nil
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - dragStart
                Main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if dragging and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
                antiBatPanelPos = {
                    XScale = Main.Position.X.Scale,
                    XOffset = Main.Position.X.Offset,
                    YScale = Main.Position.Y.Scale,
                    YOffset = Main.Position.Y.Offset,
                }
                dragging = false
                activeInput = nil
            end
        end)
    end

    antiBatPanelGui = gui
    antiBatPanelVisible = true
    setToggleVisual(antiBatEnabled)
    setInfJumpVisual(infJumpEnabled)
end

-- Keybind: J = Hold Jump aç/kapa
UIS.InputBegan:Connect(function(input, gpe)
    if gpe or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.J then
        setInfJump(not infJumpEnabled)
        if setInfJumpVisualRef then
            setInfJumpVisualRef(infJumpEnabled)
        end
        print("[HoldJump]", infJumpEnabled and "ON" or "OFF")
    end
end)

-- Karakter respawn
LP.CharacterAdded:Connect(function()
    if antiBatEnabled then
        task.delay(0.5, function()
            if antiBatEnabled then startAntiBat() end
        end)
    end
end)

-- HEMEN AÇ
createAntiBatPanel()
print("[Sakura.vs AntiBat] Panel açıldı — Anti Bat / Hold Jump | J = Hold Jump toggle")
