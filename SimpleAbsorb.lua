-- Неймспейс аддона
local AddonName, Addon = ...

-- Локальные переменные для быстрого доступа
local db
local configFrame

-- Инициализация библиотеки LibSharedMedia
local function InitLibSharedMedia()
    if LibStub then
        Addon.LSM = LibStub("LibSharedMedia-3.0", true)
    end
end

-- ---------------------------------------------------------------------------
-- Основной фрейм абсорба
-- ---------------------------------------------------------------------------

local function CreateAbsorbFrame()
    local f = CreateFrame("Frame", "SimpleAbsorbDisplayFrame", UIParent, "BackdropTemplate")
    f:SetSize(db.width or 70, db.height or 70)
    f:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(not db.locked) 
    f:RegisterForDrag("LeftButton")

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    text:SetPoint("CENTER", f, "CENTER")
    text:SetText("0")
    f.text = text

    f:SetScript("OnDragStart", function(self)
        if db.locked then return end
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        if db.locked then return end
        self:StopMovingOrSizing()
        
        local cx, cy = UIParent:GetCenter()
        local fx, fy = self:GetCenter()
        
        db.x = fx - cx
        db.y = fy - cy
        
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)

        if configFrame and configFrame:IsShown() then
            configFrame:UpdateInputs()
        end
    end)

    f:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            local total = UnitGetTotalAbsorbs("player") or 0
            self.text:SetText(AbbreviateNumbers(total))
            self.text:Show()
            if db.desaturateAtZero then
                db.bgColor[4] = total
                Addon.UpdateBackgroundColor()
            end
        end
    end)

    f:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    return f
end

-- ---------------------------------------------------------------------------
-- Инициализация аддона
-- ---------------------------------------------------------------------------

local function InitAddonDb()
    if not SimpleAbsorbDB then
        SimpleAbsorbDB = {}
    end

    db = SimpleAbsorbDB
    Addon.db = db

    -- Инициализация цвета по умолчанию, если нет
    if not db.fontColor or type(db.fontColor) ~= "table" then
        db.fontColor = {1, 1, 1, 1}  -- Полностью чёрный
    end

    -- Инициализация цвета фона по умолчанию, если нет
    if not db.bgColor or type(db.bgColor) ~= "table" then
        db.bgColor = {1, 1, 0, 0.5}  -- Желтый с прозрачностью 50%
    end

    if db.locked == nil then db.locked = false end
    if type(db.fontSize) ~= "number" then db.fontSize = 24 end

    if db.desaturateAtZero == nil then
        db.desaturateAtZero = false
    end

    if type(db.fontSize) ~= "number" then
        db.fontSize = 24  -- Размер по умолчанию
    end
end

local function UpdateConfigFrame()
    if not configFrame then
        configFrame = Addon.CreateConfigFrame()
    end

    -- Обновляем цвета на кнопках при загрузке GUI
    if configFrame._updateFontColor then
        configFrame._updateFontColor()
    end
    if configFrame._updateBgColor then
        configFrame._updateBgColor()
    end

    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

local function OnAddonLoad(self, event, addonName)
    if addonName ~= AddonName then return end

    InitLibSharedMedia()
    InitAddonDb()

    Addon.absorbFrame = CreateAbsorbFrame()
    Addon.UpdateFont()
    Addon.UpdateBackgroundColor()

    SLASH_SIMPLEABSORB1 = "/simpleabs"
    SLASH_SIMPLEABSORB2 = "/sa"
    SlashCmdList["SIMPLEABSORB"] = UpdateConfigFrame

    self:UnregisterEvent("ADDON_LOADED")
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", OnAddonLoad)
