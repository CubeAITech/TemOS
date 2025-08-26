local unicode = unicode or utf8
local component = component
local computer = computer

-- Базовая инициализация
local function initialize()
    -- Поиск экрана и GPU
    local screen_addr, gpu_addr
    
    for address, type in component.list("screen") do
        screen_addr = address
        break
    end
    
    for address, type in component.list("gpu") do
        gpu_addr = address
        break
    end
    
    if not screen_addr or not gpu_addr then
        return nil, "Требуется монитор и видеокарта"
    end
    
    -- Настройка GPU
    local gpu = component.proxy(gpu_addr)
    local success, reason = gpu.bind(screen_addr)
    if not success then
        return nil, "Ошибка подключения GPU: " .. tostring(reason)
    end
    
    gpu.setResolution(gpu.maxResolution())
    local w, h = gpu.getResolution()
    
    return {
        gpu = gpu,
        screen_width = w,
        screen_height = h
    }
end

-- Цветовая схема
local colors = {
    background = 0x1E1E1E,
    header_bg = 0x2D2D2D,
    header_text = 0xFFFFFF,
    text = 0xCCCCCC,
    accent = 0x0078D7,
    button = 0x0078D7,
    button_hover = 0x106EBE,
    button_text = 0xFFFFFF,
    disk_normal = 0x3C3C3C,
    disk_selected = 0x0078D7,
    disk_text = 0xFFFFFF,
    progress_bg = 0x444444,
    progress_fg = 0x00AA00,
    error = 0xFF4444
}

-- Функция для проверки, является ли текущий запуск установщиком
local function isInstallerRunning()
    -- Проверяем, запущен ли мы из файла установщика
    local shell = require("shell")
    local args = {...}
    
    -- Если файл называется 'installer.lua' или запущен с параметром 'install'
    if args[1] == "install" or shell.getRunningProgram():find("installer") then
        return true
    end
    
    -- Проверяем наличие метки установленной системы
    for address, type in component.list("filesystem") do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.getLabel() == "TemOS" and fs.exists("system/boot.lua") then
                return false -- Система уже установлена
            end
        end
    end
    
    return true -- По умолчанию считаем, что это установщик
end

-- Основная функция установщика
local function installerMain()
    -- Проверяем, не установлена ли уже система
    if not isInstallerRunning() then
        -- Запускаем систему вместо установщика
        local shell = require("shell")
        for address, type in component.list("filesystem") do
            if type == "filesystem" then
                local fs = component.proxy(address)
                if fs.getLabel() == "TemOS" and fs.exists("system/boot.lua") then
                    fs.setLabel("TemOS") -- Убеждаемся, что метка установлена
                    os.execute("system/boot.lua")
                    return
                end
            end
        end
        error("Система установлена, но не найдена")
    end
    
    -- Инициализация установщика
    local init_result, err = initialize()
    if not init_result then
        computer.beep(1000, 0.5)
        error(err)
    end
    
    local gpu = init_result.gpu
    local screen_width, screen_height = init_result.screen_width, init_result.screen_height
    
    -- Функция для красивого отображения текста
    local function drawText(x, y, text, color)
        color = color or colors.text
        gpu.setForeground(color)
        gpu.set(x, y, text)
    end

    -- Функция для отрисовки прямоугольника
    local function drawRect(x, y, width, height, bgColor)
        gpu.setBackground(bgColor)
        gpu.fill(x, y, width, height, " ")
    end

    -- Функция для отрисовки кнопки
    local function drawButton(x, y, width, height, text, isActive, isHovered)
        local bgColor
        if not isActive then
            bgColor = 0x555555
        else
            bgColor = isHovered and colors.button_hover or colors.button
        end
        
        drawRect(x, y, width, height, bgColor)
        drawText(math.floor(x + (width - unicode.len(text)) / 2), math.floor(y + height / 2), text, colors.button_text)
    end

    -- Функция для отрисовки элемента диска
    local function drawDiskItem(x, y, width, disk, isSelected, index)
        local bgColor = isSelected and colors.disk_selected or colors.disk_normal
        local textColor = colors.disk_text
        
        drawRect(x, y, width, 3, bgColor)
        
        -- Буква диска
        drawText(x + 2, y + 1, disk.letter .. ":", 0xAAAAAA)
        
        -- Название диска
        local nameX = x + 5
        local nameText = disk.label
        if unicode.len(nameText) > width - 10 then
            nameText = unicode.sub(nameText, 1, width - 13) .. "..."
        end
        drawText(nameX, y + 1, nameText, textColor)
        
        -- Адрес (укороченный)
        local addrText = "(" .. disk.address:sub(1, 6) .. ")"
        drawText(x + width - unicode.len(addrText) - 2, y + 1, addrText, 0x888888)
    end

    -- Функция для отрисовки прогрессбара
    local function drawProgressBar(x, y, width, height, progress, text)
        -- Фон
        drawRect(x, y, width, height, colors.progress_bg)
        
        -- Заполненная часть
        local fillWidth = math.max(1, math.floor(width * progress / 100))
        if fillWidth > 0 then
            drawRect(x, y, fillWidth, height, colors.progress_fg)
        end
        
        -- Текст
        if text then
            drawText(math.floor(x + (width - unicode.len(text)) / 2), y + 1, text, colors.text)
        end
    end
    
    -- Функция очистки экрана
    local function clearScreen()
        drawRect(1, 1, screen_width, screen_height, colors.background)
    end
    
    -- Функция отображения сообщения
    local function showMessage(message, submessage)
        clearScreen()
        
        -- Заголовок
        drawRect(1, 1, screen_width, 3, colors.header_bg)
        drawText(math.floor((screen_width - unicode.len("TemOS Installer")) / 2), 2, "TemOS Installer", colors.header_text)
        
        -- Основное сообщение
        drawText(math.floor((screen_width - unicode.len(message)) / 2), math.floor(screen_height / 2) - 1, message, colors.text)
        
        -- Дополнительное сообщение
        if submessage then
            drawText(math.floor((screen_width - unicode.len(submessage)) / 2), math.floor(screen_height / 2) + 1, submessage, 0x888888)
        end
        
        computer.pullSignal(0.1)
    end
    
    -- Показываем начальный экран
    showMessage("Загрузка установщика...", "v1.0")
    computer.pullSignal(2)
    
    -- Поиск дисков
    showMessage("Поиск дисков...")
    
    local disks = {}
    local disk_letters = {"C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"}
    local letter_index = 1
    
    for address, type in component.list("filesystem") do
        if type == "filesystem" then
            local fs = component.proxy(address)
            local label = fs.getLabel() or "Локальный диск"
            
            -- Пропускаем tmpfs и read-only файловые системы
            if label ~= "tmpfs" and not fs.isReadOnly() then
                local disk_letter = disk_letters[letter_index] or "X"
                letter_index = letter_index + 1
                
                table.insert(disks, {
                    address = address,
                    label = label,
                    letter = disk_letter,
                    proxy = fs
                })
            end
        end
    end
    
    if #disks == 0 then
        showMessage("Ошибка: Нет дисков", "Требуется диск с возможностью записи")
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Основной экран выбора диска
    local selected_disk = nil
    local hover_button = false
    
    while true do
        clearScreen()
        
        -- Заголовок
        drawRect(1, 1, screen_width, 3, colors.header_bg)
        drawText(math.floor((screen_width - unicode.len("Установка TemOS")) / 2), 2, "установка TemOS", colors.header_text)
        
        -- Инструкция
        drawText(3, 5, "Выберите диск для установки:", colors.text)
        
        -- Список дисков
        local start_y = 7
        local disk_width = math.min(50, screen_width - 6)
        local disk_x = math.floor((screen_width - disk_width) / 2)
        
        local disk_items = {}
        for i, disk in ipairs(disks) do
            local y = start_y + (i-1)*4
            disk_items[i] = {y = y, disk = disk}
            drawDiskItem(disk_x, y, disk_width, disk, selected_disk == disk, i)
        end
        
        -- Кнопки
        local buttons_y = start_y + #disks * 4 + 3
        local button_width = 20
        local button_x = math.floor((screen_width - button_width) / 2)
        
        -- Кнопка установки
        local install_active = selected_disk ~= nil
        drawButton(button_x, buttons_y, button_width, 3, "УСТАНОВИТЬ", install_active, hover_button and install_active)
        
        -- Кнопка выхода
        drawButton(button_x, buttons_y + 5, button_width, 3, "ВЫХОД", true, false)
        
        -- Футер
        drawText(math.floor((screen_width - unicode.len("TemOS")) / 2), 
                screen_height - 1, "TemOS", 0x888888)
        
        -- Ждем ввода пользователя
        local signal = {computer.pullSignal()}
        if signal[1] == "touch" then
            local x, y = signal[3], signal[4]
            
            -- Проверка выбора диска
            for i, item in ipairs(disk_items) do
                if y >= item.y and y < item.y + 3 and x >= disk_x and x < disk_x + disk_width then
                    selected_disk = item.disk
                    break
                end
            end
            
            -- Проверка кнопки установки
            if install_active and y >= buttons_y and y < buttons_y + 3 and x >= button_x and x < button_x + button_width then
                break -- Начинаем установку
            end
            
            -- Проверка кнопки выхода
            if y >= buttons_y + 5 and y < buttons_y + 8 and x >= button_x and x < button_x + button_width then
                computer.shutdown()
                return
            end
        end
    end
    
    -- Процесс установки
    showMessage("Проверка сетевого подключения...")
    
    -- Проверяем наличие интернета
    local internet_addr = component.list("internet")()
    if not internet_addr then
        showMessage("Ошибка", "Требуется сетевая карта")
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Загрузка системы
    showMessage("Подключение к серверу...", "raw.githubusercontent.com")
    
    local internet = component.proxy(internet_addr)
    local handle, err = internet.request("https://raw.githubusercontent.com/CubeAITech/TemOS/main/home/boot.lua")
    if not handle then
        showMessage("Ошибка сети", "Не удалось подключиться: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Чтение данных с прогрессом
    local content = ""
    local total_size = 0
    local chunk_count = 0
    
    showMessage("Загрузка системы...", "0%")
    
    while true do
        local chunk = handle.read()
        if not chunk then break end
        
        content = content .. chunk
        total_size = total_size + #chunk
        chunk_count = chunk_count + 1
        
        -- Обновляем прогресс каждые 5 чанков
        if chunk_count % 5 == 0 then
            local progress = math.min(100, math.floor(total_size / 500 * 100))
            showMessage("Загрузка системы...", progress .. "%")
        end
    end
    handle.close()
    
    -- Уменьшил минимальный размер проверки
    if #content < 50 then
        showMessage("Ошибка загрузки", "Файл слишком мал или поврежден: " .. #content .. " байт")
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Запись на диск
    showMessage("Запись на диск...", "Подготовка")
    
    local disk = selected_disk.proxy
    
    -- Создаем структуру папок
    disk.makeDirectory("system")
    
    -- Записываем основной файл системы
    local file, err = disk.open("system/boot.lua", "w")
    if not file then
        showMessage("Ошибка записи", "Не удалось создать system/boot.lua: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    local success, err = disk.write(file, content)
    if not success then
        disk.close(file)
        showMessage("Ошибка записи", "Не удалось записать system/boot.lua: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    disk.close(file)
    
    -- Создаем init.lua который будет запускать систему
    local init_content = [[-- TemOS Bootloader
local component = require("component")
local computer = require("computer")

-- Проверяем, установлена ли система
local function systemExists()
    for address, type in component.list("filesystem") do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.getLabel() == "TemOS" and fs.exists("system/boot.lua") then
                return true, fs
            end
        end
    end
    return false
end

-- Основная функция загрузки
local function boot()
    local exists, fs = systemExists()
    if exists then
        -- Запускаем систему
        print("Загрузка TemOS...")
        os.execute("system/boot.lua")
    else
        -- Запускаем установщик
        print("Система не найдена. Запуск установщика...")
        os.execute("installer.lua install")
    end
end

-- Запускаем загрузчик
boot()
]]
    
    local init_file, err = disk.open("init.lua", "w")
    if not init_file then
        showMessage("Ошибка записи", "Не удалось создать init.lua: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    success, err = disk.write(init_file, init_content)
    if not success then
        disk.close(init_file)
        showMessage("Ошибка записи", "Не удалось записать init.lua: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    disk.close(init_file)
    
    -- Установка метки
    pcall(disk.setLabel, "TemOS")
    
    -- Финальный экран
    clearScreen()
    drawRect(1, 1, screen_width, 3, colors.header_bg)
    drawText(math.floor((screen_width - unicode.len("Установка завершена!")) / 2), 2, "Установка завершена!", colors.header_text)
    
    drawText(math.floor((screen_width - unicode.len("TemOS успешно установлена на диск " .. selected_disk.letter)) / 2), 
            math.floor(screen_height / 2) - 2, "TemOS успешно установлена на диск " .. selected_disk.letter, colors.text)
    
    drawText(math.floor((screen_width - unicode.len("Компьютер будет перезагружен")) / 2), 
            math.floor(screen_height / 2), "Компьютер будет перезагружен", 0x888888)
    
    drawText(math.floor((screen_width - unicode.len("Система будет запущена автоматически")) / 2), 
            math.floor(screen_height / 2) + 2, "Система будет запущена автоматически", 0x00FF00)
    
    drawProgressBar(math.floor((screen_width - 40) / 2), math.floor(screen_height / 2) + 5, 40, 2, 100, "Готово!")
    
    computer.pullSignal(3)
    computer.shutdown(true)
end

-- Главная функция
local function main()
    if isInstallerRunning() then
        -- Запускаем установщик
        local ok, err = pcall(installerMain)
        if not ok then
            -- Обработка ошибок установщика
            local gpu_addr = component.list("gpu")()
            if gpu_addr then
                local gpu = component.proxy(gpu_addr)
                local screen_addr = component.list("screen")()
                if screen_addr and pcall(gpu.bind, screen_addr) then
                    gpu.setResolution(80, 25)
                    gpu.setBackground(0x000000)
                    gpu.setForeground(0xFFFFFF)
                    gpu.fill(1, 1, 80, 25, " ")
                    gpu.set(1, 1, "Ошибка установщика: " .. tostring(err))
                end
            end
            computer.pullSignal(3)
        end
    else
        -- Запускаем систему
        for address, type in component.list("filesystem") do
            if type == "filesystem" then
                local fs = component.proxy(address)
                if fs.getLabel() == "TemOS" and fs.exists("system/boot.lua") then
                    os.execute("system/boot.lua")
                    return
                end
            end
        end
        error("Система не найдена")
    end
end

-- Запуск
local ok, err = pcall(main)
if not ok then
    -- Простой вывод ошибки
    local gpu_addr = component.list("gpu")()
    if gpu_addr then
        local gpu = component.proxy(gpu_addr)
        local screen_addr = component.list("screen")()
        if screen_addr and pcall(gpu.bind, screen_addr) then
            gpu.setResolution(80, 25)
            gpu.setBackground(0x000000)
            gpu.setForeground(0xFFFFFF)
            gpu.fill(1, 1, 80, 25, " ")
            gpu.set(1, 1, "Критическая ошибка: " .. tostring(err))
        end
    end
    computer.pullSignal(3)
end
computer.shutdown()
