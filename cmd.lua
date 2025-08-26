local cursorX = 1
local cursorY = 1
local screenWidth = 80
local screenHeight = 25
local sys = {}

function initialize()
    for address, type in component.list() do
        if type == "gpu" then
            sys.gpu = component.proxy(address)
            break
        end
    end
    
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
    
    for address, type in component.list() do
        if type == "beep" then
            sys.beep = component.proxy(address)
            break
        end
    end
    
    for address, type in component.list() do
        if type == "keyboard" then
            sys.keyboard = address
            break
        end
    end
    
    return true
end

function print(text)
    if not sys.gpu then
        return false
    end
    
    local textStr = tostring(text)
    
    if cursorX + #textStr > screenWidth then
        newline()
    end
    
    sys.gpu.set(cursorX, cursorY, textStr)
    cursorX = cursorX + #textStr
    
    return true
end

function newline()
    cursorX = 1
    cursorY = cursorY + 1
    
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

-- Проверка существования файла через component.filesystem
function fileExists(path)
    -- Ищем любую файловую систему
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.exists and fs.isDirectory then
                if pcall(function() return fs.exists(path) end) then
                    return fs.exists(path)
                end
            end
        end
    end
    return false
end

-- Загрузка файла через component.filesystem
function loadFile(path)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.open and fs.read then
                local handle, reason = fs.open(path, "r")
                if handle then
                    local content = ""
                    while true do
                        local chunk = fs.read(handle, math.huge)
                        if not chunk then break end
                        content = content .. chunk
                    end
                    fs.close(handle)
                    return content
                end
            end
        end
    end
    error("Невозможно прочитать файл: " .. path)
end

-- Загрузка и выполнение файла
function dofile(path)
    local content = loadFile(path)
    local func, reason = load(content, "=" .. path)
    if not func then
        error("Ошибка загрузки или выполнения файла: " .. tostring(reason))
    end
    return func()
end

-- Получение информации о дисках
function getDiskInfo()
    local disks = {}
    
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.spaceTotal and fs.spaceUsed then
                local total = fs.spaceTotal()
                local used = fs.spaceUsed()
                local free = total - used
                local label = fs.getLabel() or "Диск " .. address:sub(1, 6)
                
                table.insert(disks, {
                    address = address,
                    label = label,
                    total = total,
                    used = used,
                    free = free,
                    percent = total > 0 and math.floor((used / total) * 100) or 0
                })
            end
        end
    end
    
    return disks
end

-- Отображение информации о дисках
function showDiskInfo()
    local disks = getDiskInfo()
    
    if #disks == 0 then
        print("Диски не найдены")
        newline()
        return
    end
    
    print("Сторонние девайсы:")
    newline()
    
    for i, disk in ipairs(disks) do
        print("  " .. disk.label .. ":")
        print(string.format("    Использовано: %d/%d байт (%d%%)", 
            disk.used, disk.total, disk.percent))
        print(string.format("    Доступно: %d bytes", disk.free))
        newline()
    end
end

-- Показать информацию о системе
function showInfo()
    clear()
    print("BIOS")
    newline()
    print("Память: " .. computer.totalMemory() .. "K")
    print("Заряд: " .. math.floor(computer.energy()))
    newline()
    
    if sys.gpu then
        print("Размер экрана: " .. screenWidth .. "x" .. screenHeight)
        newline()
    end
    
    print("Установленные компоненты:")
    newline()
    for address, type in component.list() do
        print("  " .. type)
        newline()
    end
    
    newline()
    showDiskInfo()
end

-- Интерактивное меню BIOS
function showMenu()
    clear()
    print("BIOS - Главное меню")
    newline()
    newline()
    newline()
    newline()
    print("1. Запуск OS из диска (/boot/init.lua)")
    newline()
    print("2. Показать системную информацию")
    newline()
    print("3. Показать дисковую информацию")
    newline()
    print("4. Перезапуск")
    newline()
    print("5. Выход из системы")
    newline()
    newline()
    newline()
    newline()
    print("Выберите опцию (1-5): ")
    
    local selected = nil
    while not selected do
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            if key >= 2 and key <= 6 then -- 1-5 keys
                selected = key - 1
            end
        end
    end
    
    return selected
end

-- Загрузка ОС (опциональная)
function bootOS()
    if not fileExists("/boot/init.lua") then
        clear()
        print("OS не найдена: /boot/init.lua")
        newline()
        print("Нажмите на любую кнопку для того что бы вернуться в меню...")
        
        -- Ожидание клавиши
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                break
            end
        end
        return false
    end
    
    -- Загрузка ОС
    local ok, err = pcall(dofile, "/boot/init.lua")
    if not ok then
        clear()
        print("Ошибка OS:")
        print(err)
        newline()
        print("Нажмите на любую кнопку для того что бы вернуться в меню...")
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                break
            end
        end
        return false
    end
    
    return true
end

-- Главная функция
function main()
    -- Инициализация системы
    if not initialize() then
        return
    end
    
    -- Короткий звук при запуске
    if sys.beep then
        sys.beep.beep(1500, 0.1)
    end
    
    -- Главный цикл меню
    while true do
        local choice = showMenu()
        
        if choice == 1 then
            -- Попытка загрузки ОС
            if bootOS() then
                break -- Выход из цикла если ОС загрузилась успешно
            end
            
        elseif choice == 2 then
            showInfo()
            newline()
            print("Нажмите на любую кнопку для того что бы вернуться в меню...")
            while true do
                local event = {computer.pullSignal()}
                if event[1] == "key_down" then
                    break
                end
            end
            
        elseif choice == 3 then
            clear()
            showDiskInfo()
            newline()
            print("Нажмите на любую кнопку для того что бы вернуться в меню...")
            while true do
                local event = {computer.pullSignal()}
                if event[1] == "key_down" then
                    break
                end
            end
            
        elseif choice == 4 then
            computer.shutdown(true)
            
        elseif choice == 5 then
            computer.shutdown()
        end
    end
end

-- Обработчик ошибок
function handleError(err)
    if sys.beep then
        sys.beep.beep(300, 0.5)
    end
    if sys.gpu then
        clear()
        print("Ошибка BIOS:")
        print(err)
        newline()
        print("Система остановлена*.")
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
