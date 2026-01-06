-- Неймспейс аддона
local AddonName, Addon = ...

-- Локальные ссылки на часто используемые данные
local db, absorbFrame, LSM

-- Функция инициализации локальных ссылок
local function InitModuleReferences()
    db = Addon.db
    absorbFrame = Addon.absorbFrame
    LSM = Addon.LSM
end

-- ---------------------------------------------------------------------------
-- Функции обновления
-- ---------------------------------------------------------------------------

function Addon.UpdateFont()
    InitModuleReferences()
    if not absorbFrame or not absorbFrame.text then return end

    local fontPath
    if LSM and db.font then
        fontPath = LSM:Fetch("font", db.font, true)
    end

    if not fontPath then
        fontPath = STANDARD_TEXT_FONT
    end

    local size = db.fontSize or 24
    local flag = db.fontFlag or "OUTLINE"

    absorbFrame.text:SetFont(fontPath, size, flag)
    absorbFrame.text:SetTextColor(unpack(db.fontColor))
end

function Addon.UpdateBackgroundColor()
    InitModuleReferences()
    if not absorbFrame then return end

    -- Устанавливаем бэкграунд
    absorbFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16
    })

    -- Применяем цвет из настроек
    if db.bgColor and type(db.bgColor) == "table" then
        local r = db.bgColor[1] or 1
        local g = db.bgColor[2] or 1
        local b = db.bgColor[3] or 1
        local a = db.bgColor[4] or 1
        absorbFrame:SetBackdropColor(r, g, b, a)
    else
        -- Цвет по умолчанию
        absorbFrame:SetBackdropColor(1, 1, 0, 1)
    end
end
