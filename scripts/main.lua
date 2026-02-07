print("=== [Custom Server Button] MOD LOADING ===\n")

local UEHelpers = require("UEHelpers")
local Config = require("../config")
local DEBUG = Config.Debug or false

local SERVER_IP = Config.IP or "127.0.0.1"
local SERVER_PORT = Config.Port or 7777
local SERVER_PASSWORD = Config.Password or ""
local BUTTON_TEXT = Config.ButtonText or "Custom Server Button"
local BUTTON_ICON = Config.Icon

-- Cached references (cleared on gameplay enter)
local CustomServerBtn = CreateInvalidObject()
local ButtonIconTexture = CreateInvalidObject()

local function Log(message, level)
    level = level or "info"

    if level == "debug" and not DEBUG then
        return
    end

    local prefix = ""
    if level == "error" then
        prefix = "ERROR: "
    elseif level == "warning" then
        prefix = "WARNING: "
    end

    print("[Custom Server Button] " .. prefix .. tostring(message) .. "\n")
end


local function validateConfig()
    if SERVER_IP and type(SERVER_IP) ~= "string" then
        Log("Invalid server address in config, using 127.0.0.1", "error")
        SERVER_IP = "127.0.0.1"
    end

    if SERVER_PORT and (type(SERVER_PORT) ~= "number" or SERVER_PORT <= 0) then
        Log("Invalid port in config, using 7777", "error")
        SERVER_PORT = 7777
    end
end

validateConfig()

local function ConvertColor(colorConfig, defaultR, defaultG, defaultB)
    if not colorConfig or type(colorConfig) ~= "table" then
        return { R = defaultR / 255, G = defaultG / 255, B = defaultB / 255, A = 1.0 }
    end
    return {
        R = (tonumber(colorConfig.R) or defaultR) / 255,
        G = (tonumber(colorConfig.G) or defaultG) / 255,
        B = (tonumber(colorConfig.B) or defaultB) / 255,
        A = 1.0
    }
end

local BUTTON_TEXT_COLOR = ConvertColor(Config.TextColor, 42, 255, 45)

-- Clear cached references when entering gameplay (menu widgets destroyed)
RegisterInitGameStatePreHook(function()
    CustomServerBtn = CreateInvalidObject()
    ButtonIconTexture = CreateInvalidObject()
end)


local function CreateButton()
    if CustomServerBtn:IsValid() then
        return CustomServerBtn
    end

    -- Find live runtime canvas instance
    -- RF_NoFlags = no required flags, RF_WasLoaded = exclude blueprint templates loaded from disk
    -- Runtime instances don't have RF_WasLoaded, while blueprint templates do
    local Canvas = FindObject("CanvasPanel", "CanvasPanel_42", EObjectFlags.RF_NoFlags, EObjectFlags.RF_WasLoaded)
    if not Canvas:IsValid() then
        Log("Canvas not found (not in main menu)", "debug")
        return nil
    end

    local ButtonClass = StaticFindObject("/Game/Blueprints/Widgets/MenuSystem/W_MainMenuButton.W_MainMenuButton_C")
    if not ButtonClass:IsValid() then
        Log("Button class not found", "error")
        return nil
    end

    local btn = StaticConstructObject(ButtonClass, Canvas, FName("Button_CustomServer"))
    if not btn:IsValid() then
        Log("Failed to create button", "error")
        return nil
    end

    if BUTTON_ICON and BUTTON_ICON ~= "" then
        if not ButtonIconTexture:IsValid() then
            local texture = StaticFindObject("/Game/Textures/GUI/Icons/" .. BUTTON_ICON .. "." .. BUTTON_ICON)
            if texture:IsValid() then
                ButtonIconTexture = texture
            end
        end
        if ButtonIconTexture:IsValid() then
            btn.Icon = ButtonIconTexture
        end
    end

    btn.RenderTransform.Scale = { X = 0.8, Y = 0.8 }
    btn.DefaultTextColor = BUTTON_TEXT_COLOR

    local Slot = Canvas:AddChildToCanvas(btn)
    if Slot:IsValid() then
        Slot:SetPosition({ X = 155, Y = 680.0 })
        Slot:SetAnchors({ Min = { X = 0.0, Y = 1.0 }, Max = { X = 0.0, Y = 1.0 } })
    end

    local labelText = btn.ButtonLabelText
    if labelText:IsValid() then
        labelText:SetText(FText(BUTTON_TEXT))
    end

    CustomServerBtn = btn
    return btn
end

local function ConnectToServer()
    local Master = FindFirstOf("W_MainMenu_Master_C")
    if not Master:IsValid() then
        Log("Master menu not found", "error")
        return
    end

    local ServerBrowser = Master.W_ServerBrowser
    if not ServerBrowser:IsValid() then
        Log("ServerBrowser not found", "error")
        return
    end

    local KismetSystemLibrary = UEHelpers.GetKismetSystemLibrary()
    if not KismetSystemLibrary:IsValid() then
        Log("KismetSystemLibrary not found", "error")
        return
    end

    local cmd = "open " .. SERVER_IP .. ":" .. tostring(SERVER_PORT)
    if SERVER_PASSWORD ~= "" then
        cmd = cmd .. "?pw=" .. SERVER_PASSWORD
    end

    Log("Connecting to " .. SERVER_IP .. ":" .. tostring(SERVER_PORT))
    pcall(function()
        KismetSystemLibrary:ExecuteConsoleCommand(ServerBrowser, cmd, nil)
    end)
end

-- Hook mainmenu button clicks - when clicked it means a menu exists, so create our custom button (if not already present)
local hookRegistered = false

local function TryRegisterHook()
    if hookRegistered then return true end

    local success, errorMsg = pcall(RegisterHook,
        "/Game/Blueprints/Widgets/MenuSystem/W_MainMenuButton.W_MainMenuButton_C:BndEvt__AbioticButton_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature",
        function(Context)
            local btn = Context:get()
            if not btn:IsValid() then return end

            if not CustomServerBtn:IsValid() then
                CreateButton()
            end

            local fullName = btn:GetFullName()
            if fullName:find("Button_CustomServer") then
                ConnectToServer()
            end
        end)

    if success then
        hookRegistered = true
        return true
    else
        Log("Hook registration failed: " .. tostring(errorMsg), "debug")
        return false
    end
end

if not TryRegisterHook() then
    local retryCount = 0
    local function retry()
        if TryRegisterHook() or retryCount >= 10 then
            return
        end
        retryCount = retryCount + 1
        ExecuteWithDelay(2000, retry)
    end
    retry()
end

Log("Mod loaded", "debug")
