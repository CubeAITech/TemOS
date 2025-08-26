local cursorX = 1
local cursorY = 1
local screenWidth = 80
local screenHeight = 25
local sys = {}
local settings = {
    textColor = 0xFFFFFF,      -- Белый по умолчанию
    bgColor = 0x000000,        -- Черный по умолчанию
    fontSize = 1,              -- Размер шрифта (1-6)
    beepEnabled = true,        -- Звуковые эффекты
    autoBoot = false           -- Автозагрузка ОС
}

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
                    sys.gpu.setBackground(settings.bgColor)
                    sys.gpu.setForeground(settings.textColor)
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
    
    -- Загрузка сохраненных настроек
    loadSettings()
    
    return true
end

-- Вспомогательная функция для trim
function string.trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Загрузка настроек из файла
function loadSettings()
    if fileExists("/bios/settings.cfg") then
        local content = loadFile("/bios/settings.cfg")
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("^([^=]+)=(.+)$")
            if key and value then
                key = key:trim()
                value = value:trim()
                
                if key == "textColor" or key == "bgColor" then
                    settings[key] = tonumber(value) or settings[key]
                elseif key == "fontSize" then
                    settings[key] = math.max(1, math.min(6, tonumber(value) or settings[key]))
                elseif key == "beepEnabled" or key == "autoBoot" then
                    settings[key] = (value:lower() == "true")
                end
            end
        end
        applySettings()
    end
end

-- Сохранение настроек в файл
function saveSettings()
    local content = ""
    for key, value in pairs(settings) do
        if type(value) == "boolean" then
            content = content .. key .. "=" .. tostring(value) .. "\n"
        else
            content = content .. key .. "=" .. tostring(value) .. "\n"
        end
    end
    
    -- Создаем директорию /bios если ее нет
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.makeDirectory and not (fs.exists("/bios") and not fs.isDirectory("/bios")) then
                if not fs.exists("/bios") then
                    fs.makeDirectory("/bios")
                end
            end
        end
    end
    
    -- Сохраняем настройки
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.open and fs.write then
                local handle, reason = fs.open("/bios/settings.cfg", "w")
                if handle then
                    fs.write(handle, content)
                    fs.close(handle)
                    return true
                end
            end
        end
    end
    return false
end

-- Применение текущих настроек
function applySettings()
    if sys.gpu then
        sys.gpu.setBackground(settings.bgColor)
        sys.gpu.setForeground(settings.textColor)
        -- Попытка установить шрифт, если поддерживается
        if sys.gpu.setFont then
            pcall(function() 
                local maxFont = 1
                -- Определяем максимальный поддерживаемый размер шрифта
                for i = 1, 6 do
                    if pcall(function() return sys.gpu.setFont(i) end) then
                        maxFont = i
                    else
                        break
                    end
                end
                settings.fontSize = math.min(settings.fontSize, maxFont)
                sys.gpu.setFont(settings.fontSize) 
            end)
        end
    end
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
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.exists and fs.isDirectory then
                if pcall(function() return fs.exists(path) end) then
                    return fs.exists(path) and not fs.isDirectory(path)
                end
            end
        end
    end
    return false
end

-- Проверка существования директории
function dirExists(path)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.exists and fs.isDirectory then
                if pcall(function() return fs.exists(path) and fs.isDirectory(path) end) then
                    return true
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

-- Запись в файл
function writeFile(path, content)
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.open and fs.write then
                local handle, reason = fs.open(path, "w")
                if handle then
                    fs.write(handle, content)
                    fs.close(handle)
                    return true
                end
            end
        end
    end
    return false
end

-- Список файлов в директории
function listFiles(path)
    local files = {}
    for address, type in component.list() do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.list and fs.isDirectory then
                if pcall(function() return fs.isDirectory(path) end) then
                    local list = fs.list(path)
                    for _, file in ipairs(list) do
                        table.insert(files, file)
                    end
                    return files
                end
            end
        end
    end
    return files
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

-- Функция для отображения меню настроек
function showSettingsMenu()
    local currentOption = 1
    local options = {
        "Цвет текста: " .. string.format("#%06X", settings.textColor),
        "Цвет фона: " .. string.format("#%06X", settings.bgColor),
        "Размер шрифта: " .. settings.fontSize,
        "Звуковые эффекты: " .. (settings.beepEnabled and "Вкл" or "Выкл"),
        "Автозагрузка ОС: " .. (settings.autoBoot and "Вкл" or "Выкл"),
        "Сохранить и выйти",
        "Выход без сохранения"
    }
    
    while true do
        clear()
        print("=== НАСТРОЙКИ BIOS ===")
        newline()
        
        for i, option in ipairs(options) do
            if i == currentOption then
                print("> " .. option)
            else
                print("  " .. option)
            end
            newline()
        end
        
        newline()
        print("Стрелки - навигация, Пробел - изменить, Enter - выбрать")
        print("Esc - выход")
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            -- Правильные коды стрелок для OpenComputers
            if key == 208 then -- Стрелка вверх
                currentOption = currentOption > 1 and currentOption - 1 or #options
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 200 then -- Стрелка вниз
                currentOption = currentOption < #options and currentOption + 1 or 1
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 57 then -- Пробел (изменить настройку)
                if currentOption == 1 then
                    changeColorSetting("textColor")
                elseif currentOption == 2 then
                    changeColorSetting("bgColor")
                elseif currentOption == 3 then
                    changeFontSize()
                elseif currentOption == 4 then
                    settings.beepEnabled = not settings.beepEnabled
                    if settings.beepEnabled and sys.beep then
                        sys.beep.beep(1000, 0.1)
                    end
                elseif currentOption == 5 then
                    settings.autoBoot = not settings.autoBoot
                    if settings.beepEnabled and sys.beep then
                        sys.beep.beep(1000, 0.1)
                    end
                end
                
            elseif key == 28 then -- Enter (выбрать пункт)
                if currentOption == 6 then
                    if saveSettings() then
                        applySettings()
                        if settings.beepEnabled and sys.beep then
                            sys.beep.beep(1200, 0.1)
                        end
                        return true
                    else
                        print("Ошибка сохранения настроек!")
                        newline()
                        print("Нажмите любую клавишу...")
                        computer.pullSignal()
                    end
                elseif currentOption == 7 then
                    applySettings() -- Восстанавливаем старые настройки
                    return false
                end
                
            elseif key == 1 then -- Esc
                applySettings()
                return false
            end
        end
    end
end

-- Функция для изменения цвета
function changeColorSetting(settingType)
    local colors = {
        {name = "Белый", value = 0xFFFFFF},
        {name = "Черный", value = 0x000000},
        {name = "Красный", value = 0xFF0000},
        {name = "Зеленый", value = 0x00FF00},
        {name = "Синий", value = 0x0000FF},
        {name = "Желтый", value = 0xFFFF00},
        {name = "Голубой", value = 0x00FFFF},
        {name = "Пурпурный", value = 0xFF00FF}
    }
    
    local currentIndex = 1
    for i, color in ipairs(colors) do
        if color.value == settings[settingType] then
            currentIndex = i
            break
        end
    end
    
    while true do
        clear()
        print("Выберите цвет для " .. (settingType == "textColor" and "текста" or "фона"))
        newline()
        
        for i, color in ipairs(colors) do
            if i == currentIndex then
                print("> " .. color.name)
            else
                print("  " .. color.name)
            end
            newline()
        end
        
        newline()
        print("Стрелки - выбор, Enter - подтвердить, Esc - отмена")
        
        -- Временно применяем выбранный цвет для предпросмотра
        local tempValue = colors[currentIndex].value
        if settingType == "textColor" then
            sys.gpu.setForeground(tempValue)
        else
            sys.gpu.setBackground(tempValue)
        end
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 208 then -- Стрелка вверх
                currentIndex = currentIndex > 1 and currentIndex - 1 or #colors
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 200 then -- Стрелка вниз
                currentIndex = currentIndex < #colors and currentIndex + 1 or 1
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(800, 0.05)
                end
                
            elseif key == 28 then -- Enter
                settings[settingType] = colors[currentIndex].value
                applySettings()
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(1200, 0.1)
                end
                return
                
            elseif key == 1 then -- Esc
                applySettings()
                return
            end
        end
    end
end

-- Функция для изменения размера шрифта
function changeFontSize()
    while true do
        clear()
        print("Выберите размер шрифта (1-6)")
        newline()
        print("Текущий размер: " .. settings.fontSize)
        newline()
        print("Стрелки влево/вправо - изменить")
        newline()
        print("Enter - подтвердить, Esc - отмена")
        
        -- Проверяем поддержку шрифтов
        local maxSupported = 1
        if sys.gpu and sys.gpu.setFont then
            for i = 1, 6 do
                if pcall(function() return sys.gpu.setFont(i) end) then
                    maxSupported = i
                else
                    break
                end
            end
        end
        
        if maxSupported == 1 then
            print("Смена шрифтов не поддерживается!")
            newline()
        end
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 203 then -- Стрелка влево
                settings.fontSize = math.max(1, settings.fontSize - 1)
                applySettings()
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(700, 0.05)
                end
                
            elseif key == 205 then -- Стрелка вправо
                settings.fontSize = math.min(6, math.min(maxSupported, settings.fontSize + 1))
                applySettings()
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(700, 0.05)
                end
                
            elseif key == 28 then -- Enter
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(1200, 0.1)
                end
                return
                
            elseif key == 1 then -- Esc
                return
            end
        end
    end
end

-- Упрощенная командная строка
function simpleCommandLine()
    clear()
    print("=== ROOT Управление ===")
    newline()
    print("Введите команду ниже (или юзайте exit для выхода):")
    newline()
    
    while true do
        print("ROOT> ")
        local currentCommand = ""
        local inputX = cursorX  -- Запоминаем позицию X после "BIOS> "
        local inputY = cursorY  -- Запоминаем позицию Y
        
        while true do
            local event = {computer.pullSignal()}
            if event[1] == "key_down" then
                local key = event[4]
                local char = event[3] -- Символ в OpenComputers находится в event[3]
                
                if key == 28 then -- Enter
                    if currentCommand:lower() == "exit" then
                        return
                    end
                    newline()  -- Переходим на новую строку перед выводом результата
                    executeCommand(currentCommand)
                    newline()
                    break  -- Выходим из внутреннего цикла для нового ввода
                    
                elseif key == 14 then -- Backspace
                    if #currentCommand > 0 then
                        currentCommand = currentCommand:sub(1, -2)
                        -- Очищаем только область ввода и перерисовываем
                        sys.gpu.fill(inputX, inputY, screenWidth - inputX + 1, 1, " ")
                        sys.gpu.set(inputX, inputY, currentCommand)
                        cursorX = inputX + #currentCommand
                        cursorY = inputY
                    end
                    
                elseif char and char >= 32 and char <= 126 then
                    currentCommand = currentCommand .. string.char(char)
                    sys.gpu.set(inputX + #currentCommand - 1, inputY, string.char(char))
                    cursorX = inputX + #currentCommand
                    cursorY = inputY
                end
            end
        end
    end
end

-- Выполнение команды
function executeCommand(cmd)
    local args = {}
    for arg in cmd:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args == 0 then
        return
    end
    
    local command = args[1]:lower()
    
    if command == "help" then
        print("Справка по командам:")
        newline()
        newline()
        newline()
        print("help    - показать эти кмд")
        newline()
        print("cls     - очистить экран фулл")
        newline()
        print("dir     - список файлов в этой папке")
        newline()
        print("dir <path> - список файлов в указанной папке")
        newline()
        print("type <file> - чекнуть содержимое файла")
        newline()
        print("info    - инфа о системе")
        newline()
        print("disks   - инфа о дисках")
        newline()
        print("beep    - тест звук сигнала (не доработнано)")
        newline()
        print("reboot  - релог пк")
        newline()
        print("shutdown - вырубить пк")
        newline()
        print("exit    - лив из рут")
        
    elseif command == "cls" then
        clear()
        return
        
    elseif command == "dir" then
        local path = args[2] or "/"
        print("Содержимое " .. path .. ":")
        newline()
        
        if dirExists(path) then
            local files = listFiles(path)
            for _, file in ipairs(files) do
                local fullPath = path .. (path:sub(-1) == "/" and "" or "/") .. file
                if dirExists(fullPath) then
                    print("[DIR]  " .. file)
                else
                    print("       " .. file)
                end
            end
        else
            print("Директория не существует: " .. path)
        end
        
    elseif command == "type" then
        if #args < 2 then
            print("Ошибка: укажите имя файла")
            return
        end
        
        local filename = args[2]
        
        if fileExists(filename) then
            local content = loadFile(filename)
            print("Содержимое файла " .. filename .. ":")
            newline()
            print(content)
        else
            print("Файл не существует: " .. filename)
        end
        
    elseif command == "info" then
        showInfo()
        
    elseif command == "disks" then
        showDiskInfo()
        
    elseif command == "beep" then
        if sys.beep then
            sys.beep.beep(1000, 0.3)
            print("Звуковой сигнал воспроизведен")
        else
            print("Звуковое устройство не найдено")
        end
        
    elseif command == "reboot" then
        computer.shutdown(true)
        
    elseif command == "shutdown" then
        computer.shutdown()
        
    elseif command == "exit" then
        return true
        
    else
        print("Неизвестная команда: " .. command)
        print("Введите 'help' для списка команд")
    end
    
    newline()
    print("Нажмите любую клавишу для продолжения...")
    computer.pullSignal()
    return false
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
    print("4. Настройки BIOS")
    newline()
    print("5. Простая командная строка")
    newline()
    print("6. Перезапуск")
    newline()
    print("7. Выход из системы")
    newline()
    newline()
    newline()
    newline()
    print("Выберите опцию (1-7): ")
    
    local selected = nil
    while not selected do
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            if key >= 2 and key <= 8 then -- 1-7 keys
                selected = key - 1
                if settings.beepEnabled and sys.beep then
                    sys.beep.beep(1000, 0.1)
                end
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
    
    -- Автозагрузка ОС если включена
    if settings.autoBoot then
        if bootOS() then
            return
        end
    end
    
    -- Короткий звук при запуске
    if settings.beepEnabled and sys.beep then
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
            showSettingsMenu()
            
        elseif choice == 5 then
            simpleCommandLine()
            
        elseif choice == 6 then
            computer.shutdown(true)
            
        elseif choice == 7 then
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
        print("Система остановлена.")
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
