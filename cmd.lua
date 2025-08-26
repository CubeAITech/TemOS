-- OpenComputers BIOS
-- Версия 2.2 (исправлены методы GPU)

-- Таблица для хранения компонентов системы
local sys = {
    gpu = nil,
    screen = nil,
    keyboard = nil,
    beep = nil,
    initialized = false,
    cursorX = 1,
    cursorY = 1
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
    
    local currentX = x or sys.cursorX
    local currentY = y or sys.cursorY
    
    sys.gpu.set(currentX, currentY, tostring(text))
    
    -- Обновляем позицию курсора
    local textLength = #tostring(text)
    sys.cursorX = currentX + textLength
    sys.cursorY = currentY
    
    return true
end

-- Функция очистки экрана
function clear()
    if sys.gpu and sys.screen then
        local width, height = sys.gpu.getResolution()
        sys.gpu.fill(1, 1, width, height, " ")
        sys.cursorX = 1
        sys.cursorY = 1
        return true
    end
    return false
end

-- Переход на новую строку
function newline()
    sys.cursorX = 1
    sys.cursorY = sys.cursorY + 1
    -- Проверка на выход за границы экрана
    local _, height = sys.gpu.getResolution()
    if sys.cursorY > height then
        sys.cursorY = height
        -- Прокрутка экрана вверх
        sys.gpu.copy(1, 2, width, height - 1, 0, -1)
        sys.gpu.fill(1, height, width, 1, " ")
    end
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
        print("OpenComputers BIOS v2.2")
        print("========================")
        newline()
        print("ОС не найдена!")
        print("Файл /boot/init.lua отсутствует")
        newline()
        print("Вставьте диск с операционной системой")
        print("или установите ОС")
        newline()
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
        newline()
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
    print("OpenComputers BIOS v2.2")
    print("========================")
    newline()
    print("Память: " .. computer.totalMemory() .. "K")
    print("Энергия: " .. math.floor(computer.energy()))
    newline()
    
    if sys.gpu then
        local width, height = sys.gpu.getResolution()
        print("Разрешение: " .. width .. "x" .. height)
        newline()
    end
    
    -- Информация о компонентах
    print("Доступные компоненты:")
    newline()
    for type in component.list() do
        print("  " .. type)
        newline()
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
    local delay = 1000000
    while delay > 0 do
        delay = delay - 1
    end
    
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
        newline()
        print("Система остановлена")
    end
    while true do computer.pullSignal() end
end

-- Точка входа с обработкой ошибок
local success, err = pcall(main)
if not success then
    errorHandler(err)
end
