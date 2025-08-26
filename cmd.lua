-- OpenComputers BIOS
-- Версия 2.1 (без require и paint)

-- Таблица для хранения компонентов системы
local sys = {
    gpu = nil,
    screen = nil,
    keyboard = nil,
    beep = nil,
    initialized = false
}

-- Имитация require через component.proxy
function loadComponent(componentType)
    for address in component.list(componentType) do
        return component.proxy(address)
    end
    return nil
end

-- Основная функция инициализации
function initialize()
    -- Поиск и инициализация GPU
    sys.gpu = loadComponent("gpu")
    if sys.gpu then
        -- Поиск звукового сигнала
        sys.beep = loadComponent("beep")
        if sys.beep then
            sys.beep.beep(1000, 0.1) -- Короткий звуковой сигнал
        end
        
        -- Автопоиск экрана и подключение
        for address in component.list("screen") do
            if sys.gpu.getScreen() ~= address then
                if pcall(function() sys.gpu.bind(address) end) then
                    sys.screen = address
                    break
                end
            else
                sys.screen = address
                break
            end
        end
        
        -- Установка разрешения если экран найден
        if sys.screen then
            local maxWidth, maxHeight = sys.gpu.maxResolution()
            sys.gpu.setResolution(maxWidth, maxHeight)
            sys.gpu.setBackground(0x000000)
            sys.gpu.setForeground(0xFFFFFF)
            sys.gpu.fill(1, 1, maxWidth, maxHeight, " ")
        end
    end
    
    -- Поиск клавиатуры
    sys.keyboard = loadComponent("keyboard")
    
    sys.initialized = true
    return true
end

-- Функция вывода текста на экран
function print(text, x, y)
    if not sys.initialized or not sys.gpu then
        if sys.beep then
            sys.beep.beep(500, 0.2) -- Ошибка инициализации
        end
        return false
    end
    
    local currentX = x or 1
    local currentY = y or 1
    
    -- Если координаты не указаны, используем текущую позицию курсора
    if not x and not y then
        currentX, currentY = sys.gpu.getCursor()
    end
    
    sys.gpu.set(currentX, currentY, tostring(text))
    
    -- Обновляем позицию курсора
    local textLength = 0
    for i = 1, #tostring(text) do
        textLength = textLength + 1
    end
    sys.gpu.setCursor(currentX + textLength, currentY)
    
    return true
end

-- Функция очистки экрана
function clear()
    if sys.gpu and sys.screen then
        local width, height = sys.gpu.getResolution()
        sys.gpu.fill(1, 1, width, height, " ")
        sys.gpu.setCursor(1, 1)
        return true
    end
    return false
end

-- Простая проверка существования файла
function fileExists(path)
    local handle, reason = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

-- Загрузка и выполнение файла
function dofile(path)
    local handle, reason = io.open(path, "r")
    if not handle then
        error("Cannot open file: " .. tostring(reason))
    end
    
    local code = handle:read("*a")
    handle:close()
    
    local chunk, reason = load(code, "=" .. path, "t", _G)
    if not chunk then
        error("Failed to load chunk: " .. tostring(reason))
    end
    
    return chunk()
end

-- Загрузка ОС из файловой системы
function bootOS()
    if not fileExists("/boot/init.lua") then
        clear()
        print("OpenComputers BIOS v2.1")
        print("========================")
        print("ОС не найдена!")
        print("Файл /boot/init.lua отсутствует")
        print("")
        print("Вставьте диск с операционной системой")
        print("или установите ОС")
        print("")
        print("Нажмите любую клавишу для перезагрузки...")
        
        -- Ожидание нажатия клавиши
        if sys.keyboard then
            while true do
                local eventData = {computer.pullSignal()}
                if eventData[1] == "key_down" then
                    break
                end
            end
        end
        computer.shutdown(true) -- Перезагрузка
    end
    
    -- Загрузка операционной системы
    local success, reason = pcall(dofile, "/boot/init.lua")
    
    if not success then
        clear()
        print("Ошибка загрузки ОС:")
        print(tostring(reason))
        print("")
        print("Нажмите любую клавишу для перезагрузки...")
        if sys.keyboard then
            while true do
                local eventData = {computer.pullSignal()}
                if eventData[1] == "key_down" then
                    break
                end
            end
        end
        computer.shutdown(true)
    end
end

-- Отображение информации о системе
function showSystemInfo()
    clear()
    print("OpenComputers BIOS v2.1")
    print("========================")
    print("Память: " .. computer.totalMemory() .. "K")
    print("Энергия: " .. computer.energy())
    
    if sys.gpu then
        local width, height = sys.gpu.getResolution()
        print("Разрешение: " .. width .. "x" .. height)
    end
    
    -- Информация о компонентах
    print("Компоненты:")
    for type, count in pairs(component.list()) do
        print("  " .. type .. ": " .. count)
    end
end

-- Основная процедура загрузки
function main()
    -- Инициализация компонентов
    if not initialize() then
        if sys.beep then
            sys.beep.beep(200, 1) -- Длинный звук ошибки
        end
        return
    end
    
    -- Отображение информации о системе
    showSystemInfo()
    
    print("Инициализация компонентов завершена")
    print("Загрузка ОС...")
    
    if sys.beep then
        sys.beep.beep(1500, 0.1)
    end
    
    -- Небольшая задержка для отображения информации
    for i = 1, 1000000 do end -- Простая задержка
    
    -- Загрузка операционной системы
    bootOS()
end

-- Обработка ошибок
function errorHandler(err)
    if sys.beep then
        sys.beep.beep(300, 0.5)
    end
    if sys.gpu and sys.screen then
        clear()
        print("КРИТИЧЕСКАЯ ОШИБКА BIOS:")
        print(tostring(err))
        print("")
        print("Система остановлена")
    end
    while true do computer.pullSignal() end
end

-- Точка входа с обработкой ошибок
local success, err = pcall(main)
if not success then
    errorHandler(err)
end
