-- OpenComputers BIOS
-- Версия 2.3 (без setCursor и других несуществующих методов)

-- Глобальные переменные для управления курсором
local cursorX = 1
local cursorY = 1
local screenWidth = 80
local screenHeight = 25

-- Основная функция инициализации
function initialize()
    -- Поиск GPU
    for address, type in component.list() do
        if type == "gpu" then
            sys.gpu = component.proxy(address)
            break
        end
    end
    
    -- Поиск экрана и подключение GPU
    if sys.gpu then
        for address, type in component.list() do
            if type == "screen" then
                if pcall(function() sys.gpu.bind(address) end) then
                    sys.screen = address
                    screenWidth, screenHeight = sys.gpu.maxResolution()
                    sys.gpu.setResolution(screenWidth, screenHeight)
                    sys.gpu.setBackground(0x000000)
                    sys.gpu.setForeground(0xFFFFFF)
                    sys.gpu.fill(1, 1, screenWidth, screenHeight, " ")
                    break
                end
            end
        end
    end
    
    -- Поиск бипера
    for address, type in component.list() do
        if type == "beep" then
            sys.beep = component.proxy(address)
            break
        end
    end
    
    -- Поиск клавиатуры
    for address, type in component.list() do
        if type == "keyboard" then
            sys.keyboard = address
            break
        end
    end
    
    return true
end

-- Функция вывода текста
function print(text)
    if not sys.gpu then
        return false
    end
    
    local textStr = tostring(text)
    
    -- Перенос строки если текст не помещается
    if cursorX + #textStr > screenWidth then
        newline()
    end
    
    sys.gpu.set(cursorX, cursorY, textStr)
    cursorX = cursorX + #textStr
    
    return true
end

-- Переход на новую строку
function newline()
    cursorX = 1
    cursorY = cursorY + 1
    
    -- Прокрутка экрана если достигнут низ
    if cursorY > screenHeight then
        cursorY = screenHeight
        if sys.gpu then
            sys.gpu.copy(1, 2, screenWidth, screenHeight - 1, 0, -1)
            sys.gpu.fill(1, screenHeight, screenWidth, 1, " ")
        end
    end
end

-- Очистка экрана
function clear()
    if sys.gpu then
        sys.gpu.fill(1, 1, screenWidth, screenHeight, " ")
        cursorX = 1
        cursorY = 1
    end
end

-- Проверка существования файла
function fileExists(path)
    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

-- Загрузка файла
function dofile(path)
    local handle = io.open(path, "r")
    if not handle then
        error("File not found: " .. path)
    end
    
    local code = handle:read("*a")
    handle:close()
    
    local func = load(code, "=" .. path)
    if not func then
        error("Failed to load file: " .. path)
    end
    
    return func()
end

-- Загрузка ОС
function bootOS()
    if not fileExists("/boot/init.lua") then
        clear()
        print("OpenComputers BIOS v2.3")
        newline()
        print("OS not found!")
        print("Missing: /boot/init.lua")
        newline()
        print("Insert OS disk or install OS")
        newline()
        print("Press any key to reboot...")
        
        -- Ожидание клавиши
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                break
            end
        end
        computer.shutdown(true)
    end
    
    -- Загрузка ОС
    local ok, err = pcall(dofile, "/boot/init.lua")
    if not ok then
        clear()
        print("Boot error:")
        print(err)
        newline()
        print("Press any key to reboot...")
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                break
            end
        end
        computer.shutdown(true)
    end
end

-- Показать информацию о системе
function showInfo()
    clear()
    print("OpenComputers BIOS v2.3")
    newline()
    print("Memory: " .. computer.totalMemory() .. "K")
    print("Energy: " .. math.floor(computer.energy()))
    newline()
    
    if sys.gpu then
        print("Screen: " .. screenWidth .. "x" .. screenHeight)
        newline()
    end
    
    print("Components:")
    newline()
    for address, type in component.list() do
        print("  " .. type)
        newline()
    end
end

-- Главная функция
function main()
    -- Инициализация системы
    sys = {}
    if not initialize() then
        return
    end
    
    -- Показать информацию
    showInfo()
    
    print("Initialization complete")
    print("Booting OS...")
    
    -- Короткий звук
    if sys.beep then
        sys.beep.beep(1500, 0.1)
    end
    
    -- Задержка
    for i = 1, 1000000 do end
    
    -- Загрузка ОС
    bootOS()
end

-- Обработчик ошибок
function handleError(err)
    if sys.beep then
        sys.beep.beep(300, 0.5)
    end
    if sys.gpu then
        clear()
        print("BIOS ERROR:")
        print(err)
        newline()
        print("System halted")
    end
    while true do
        computer.pullSignal()
    end
end

-- Запуск
local ok, err = pcall(main)
if not ok then
    handleError(err)
end
