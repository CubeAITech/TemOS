local unicode = unicode or utf8
local component = component
local computer = computer

-- Проверка, не установлена ли уже система
local function isSystemInstalled()
    for address, type in component.list("filesystem") do
        if type == "filesystem" then
            local fs = component.proxy(address)
            if fs.exists("init.lua") and fs.exists(".temos_installed") then
                return true, fs
            end
        end
    end
    return false
end

-- Если система уже установлена, запускаем её
local already_installed, installed_fs = isSystemInstalled()
if already_installed then
    if installed_fs.exists("init.lua") then
        local handle = installed_fs.open("init.lua", "r")
        if handle then
            local content = installed_fs.read(handle, math.huge)
            installed_fs.close(handle)
            if content and #content > 0 then
                computer.beep(500, 0.1)
                local ok, err = load(content, "=init.lua")
                if ok then
                    ok, err = pcall(ok)
                    if not ok then
                        computer.beep(1000, 0.5)
                    end
                else
                    computer.beep(1000, 0.5)
                end
                return
            end
        end
    end
end

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
        screen_height = h,
        screen_addr = screen_addr,
        gpu_addr = gpu_addr
    }
end

-- Цветовая схема (улучшенная)
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
    error = 0xFF4444,
    success = 0x00CC00,
    warning = 0xFFAA00,
    info = 0x0088FF
}

-- Анимационные эффекты
local function fadeIn(gpu, width, height)
    for i = 0, 100, 5 do
        local alpha = i / 100
        gpu.setBackground(0x000000)
        gpu.fill(1, 1, width, height, " ")
        gpu.setBackground(colors.background)
        gpu.fill(1, 1, math.floor(width * alpha), height, " ")
        computer.pullSignal(0.05)
    end
    gpu.setBackground(colors.background)
    gpu.fill(1, 1, width, height, " ")
end

-- Основная функция
local function main()
    -- Инициализация
    local init_result, err = initialize()
    if not init_result then
        computer.beep(1000, 0.5)
        error(err)
    end
    
    local gpu = init_result.gpu
    local screen_width, screen_height = init_result.screen_width, init_result.screen_height
    
    -- Анимация появления
    fadeIn(gpu, screen_width, screen_height)
    
    -- Функция для красивого отображения текста
    local function drawText(x, y, text, color, shadow)
        color = color or colors.text
        if shadow then
            gpu.setForeground(0x000000)
            gpu.set(x + 1, y + 1, text)
        end
        gpu.setForeground(color)
        gpu.set(x, y, text)
    end

    -- Функция для отрисовки прямоугольника с градиентом
    local function drawRect(x, y, width, height, bgColor, gradient)
        gpu.setBackground(bgColor)
        gpu.fill(x, y, width, height, " ")
        
        if gradient then
            local gradientColor = math.floor(bgColor * 0.8)
            gpu.setBackground(gradientColor)
            gpu.fill(x, y + height - 1, width, 1, " ")
        end
    end

    -- Функция для отрисовки кнопки с анимацией
    local function drawButton(x, y, width, height, text, isActive, isHovered)
        local bgColor
        if not isActive then
            bgColor = 0x555555
        else
            bgColor = isHovered and colors.button_hover or colors.button
        end
        
        -- Тень кнопки
        gpu.setBackground(0x000000)
        gpu.fill(x + 1, y + 1, width, height, " ")
        
        -- Основная кнопка
        drawRect(x, y, width, height, bgColor, true)
        
        -- Текст кнопки
        local textX = math.floor(x + (width - unicode.len(text)) / 2)
        local textY = math.floor(y + height / 2)
        
        if isHovered and isActive then
            drawText(textX, textY - 1, text, colors.button_text, true)
        else
            drawText(textX, textY, text, colors.button_text, true)
        end
    end

    -- Функция для отрисовки элемента диска с иконкой
    local function drawDiskItem(x, y, width, disk, isSelected, index)
        local bgColor = isSelected and colors.disk_selected or colors.disk_normal
        local textColor = colors.disk_text
        
        -- Тень
        gpu.setBackground(0x000000)
        gpu.fill(x + 1, y + 1, width, 3, " ")
        
        -- Основной блок
        drawRect(x, y, width, 3, bgColor, true)
        
        -- Иконка диска
        local icon = isSelected and "◉" or "◎"
        drawText(x + 1, y + 1, icon, isSelected and 0xFFFFFF or 0x888888)
        
        -- Буква диска
        drawText(x + 3, y + 1, disk.letter .. ":", 0xAAAAAA)
        
        -- Название диска
        local nameX = x + 7
        local nameText = disk.label
        if unicode.len(nameText) > width - 12 then
            nameText = unicode.sub(nameText, 1, width - 15) .. "..."
        end
        drawText(nameX, y + 1, nameText, textColor)
        
        -- Размер диска
        local size = disk.proxy.spaceTotal() or 0
        local free = disk.proxy.spaceUsed() and (size - disk.proxy.spaceUsed()) or size
        local sizeText = math.floor(free / 1024) .. "K свободно"
        drawText(x + width - unicode.len(sizeText) - 2, y + 1, sizeText, 0x888888)
    end

    -- Функция для отрисовки анимированного прогрессбара
    local function drawProgressBar(x, y, width, height, progress, text, subtext)
        -- Тень
        gpu.setBackground(0x000000)
        gpu.fill(x + 1, y + 1, width, height, " ")
        
        -- Фон
        drawRect(x, y, width, height, colors.progress_bg, true)
        
        -- Заполненная часть с анимацией
        local fillWidth = math.max(1, math.floor(width * progress / 100))
        if fillWidth > 0 then
            -- Анимация заполнения
            for i = 1, fillWidth do
                drawRect(x, y, i, height, colors.progress_fg, true)
                if i % 3 == 0 then
                    computer.pullSignal(0.01)
                end
            end
        end
        
        -- Текст прогресса
        if text then
            drawText(math.floor(x + (width - unicode.len(text)) / 2), y + 1, text, colors.text, true)
        end
        
        -- Подтекст
        if subtext then
            drawText(math.floor(x + (width - unicode.len(subtext)) / 2), y + height + 1, subtext, 0x888888)
        end
    end
    
    -- Функция очистки экрана с анимацией
    local function clearScreen()
        for i = screen_height, 1, -1 do
            gpu.setBackground(colors.background)
            gpu.fill(1, i, screen_width, 1, " ")
            computer.pullSignal(0.01)
        end
    end
    
    -- Функция отображения сообщения с анимацией
    local function showMessage(message, submessage, messageType)
        clearScreen()
        
        -- Заголовок с градиентом
        drawRect(1, 1, screen_width, 3, colors.header_bg, true)
        
        -- Анимация появления текста заголовка
        local title = "TemOS Installer"
        for i = 1, unicode.len(title) do
            drawText(math.floor((screen_width - unicode.len(title)) / 2), 2, 
                    unicode.sub(title, 1, i), colors.header_text, true)
            computer.pullSignal(0.05)
        end
        
        -- Основное сообщение
        local messageColor = colors.text
        if messageType == "error" then
            messageColor = colors.error
        elseif messageType == "success" then
            messageColor = colors.success
        elseif messageType == "warning" then
            messageColor = colors.warning
        end
        
        drawText(math.floor((screen_width - unicode.len(message)) / 2), 
                math.floor(screen_height / 2) - 1, message, messageColor, true)
        
        -- Дополнительное сообщение
        if submessage then
            drawText(math.floor((screen_width - unicode.len(submessage)) / 2), 
                    math.floor(screen_height / 2) + 1, submessage, 0x888888, true)
        end
        
        -- Анимация мигания для важных сообщений
        if messageType == "error" or messageType == "warning" then
            for i = 1, 2 do
                drawText(math.floor((screen_width - unicode.len(message)) / 2), 
                        math.floor(screen_height / 2) - 1, message, 0xFFFFFF, true)
                computer.pullSignal(0.3)
                drawText(math.floor((screen_width - unicode.len(message)) / 2), 
                        math.floor(screen_height / 2) - 1, message, messageColor, true)
                computer.pullSignal(0.3)
            end
        end
    end
    
    -- Показываем начальный экран с анимацией
    showMessage("Загрузка установщика...", "v2.0 Enhanced", "info")
    computer.pullSignal(1.5)
    
    -- Поиск дисков
    showMessage("Сканирование системы...", "Поиск доступных дисков", "info")
    
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
                    proxy = fs,
                    size = fs.spaceTotal() or 0,
                    free = fs.spaceUsed() and (fs.spaceTotal() - fs.spaceUsed()) or fs.spaceTotal()
                })
            end
        end
    end
    
    if #disks == 0 then
        showMessage("Критическая ошибка", "Нет доступных дисков для записи", "error")
        computer.beep(1000, 0.5)
        computer.beep(800, 0.5)
        computer.beep(600, 1)
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Основной экран выбора диска
    local selected_disk = nil
    local hover_button = false
    
    while true do
        clearScreen()
        
        -- Заголовок с анимацией
        drawRect(1, 1, screen_width, 3, colors.header_bg, true)
        drawText(math.floor((screen_width - unicode.len("Установка TemOS")) / 2), 2, "Установка TemOS", colors.header_text, true)
        
        -- Инструкция
        drawText(3, 5, "Выберите диск для установки системы:", colors.text, true)
        
        -- Список дисков
        local start_y = 7
        local disk_width = math.min(60, screen_width - 6)
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
        
        -- Футер с информацией
        drawText(math.floor((screen_width - unicode.len("TemOS v2.0 - Продвинутая операционная система")) / 2), 
                screen_height - 1, "TemOS v2.0 - Продвинутая операционная система", 0x888888, true)
        
        -- Ждем ввода пользователя
        local signal = {computer.pullSignal()}
        if signal[1] == "touch" then
            local x, y = signal[3], signal[4]
            
            -- Проверка выбора диска
            for i, item in ipairs(disk_items) do
                if y >= item.y and y < item.y + 3 and x >= disk_x and x < disk_x + disk_width then
                    selected_disk = item.disk
                    computer.beep(300, 0.1)
                    break
                end
            end
            
            -- Проверка кнопки установки
            if install_active and y >= buttons_y and y < buttons_y + 3 and x >= button_x and x < button_x + button_width then
                computer.beep(500, 0.1)
                break -- Начинаем установку
            end
            
            -- Проверка кнопки выхода
            if y >= buttons_y + 5 and y < buttons_y + 8 and x >= button_x and x < button_x + button_width then
                computer.beep(400, 0.1)
                computer.shutdown()
                return
            end
        elseif signal[1] == "drag" then
            hover_button = (signal[3] >= button_x and signal[3] <= button_x + button_width and 
                           signal[4] >= buttons_y and signal[4] <= buttons_y + 3)
        end
    end
    
    -- Процесс установки
    showMessage("Проверка сетевого подключения...", "Инициализация сети", "info")
    
    -- Проверяем наличие интернета
    local internet_addr = component.list("internet")()
    if not internet_addr then
        showMessage("Сетевая ошибка", "Требуется сетевая карта для загрузки", "error")
        computer.beep(1000, 0.5)
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Загрузка системы
    showMessage("Подключение к серверу...", "raw.githubusercontent.com", "info")
    
    local internet = component.proxy(internet_addr)
    local handle, err = internet.request("https://raw.githubusercontent.com/CubeAITech/TemOS/main/home/init.lua")
    if not handle then
        showMessage("Ошибка подключения", "Не удалось подключиться: " .. tostring(err), "error")
        computer.beep(1000, 0.5)
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Чтение данных с прогрессом
    local content = ""
    local total_size = 0
    local chunk_count = 0
    
    while true do
        local chunk = handle.read()
        if not chunk then break end
        
        content = content .. chunk
        total_size = total_size + #chunk
        chunk_count = chunk_count + 1
        
        -- Обновляем прогресс
        if chunk_count % 3 == 0 then
            local progress = math.min(100, math.floor(total_size / 1000 * 100))
            drawProgressBar(math.floor((screen_width - 50) / 2), math.floor(screen_height / 2), 
                          50, 2, progress, "Загрузка: " .. progress .. "%", 
                          "Загружено: " .. math.floor(total_size/1024) .. "KB")
        end
    end
    handle.close()
    
    -- Проверка размера файла
    if #content < 100 then
        showMessage("Ошибка загрузки", "Файл поврежден или слишком мал: " .. #content .. " байт", "error")
        computer.beep(1000, 0.5)
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Запись на диск
    showMessage("Установка системы...", "Запись файлов", "info")
    
    local disk = selected_disk.proxy
    
    -- Записываем init.lua
    local file, err = disk.open("init.lua", "w")
    if not file then
        showMessage("Ошибка записи", "Не удалось создать init.lua: " .. tostring(err), "error")
        computer.beep(1000, 0.5)
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Запись с прогрессом
    local written = 0
    local chunkSize = 1024
    for i = 1, #content, chunkSize do
        local chunk = content:sub(i, i + chunkSize - 1)
        local success, err = disk.write(file, chunk)
        if not success then
            disk.close(file)
            showMessage("Ошибка записи", "Ошибка при записи: " .. tostring(err), "error")
            computer.beep(1000, 0.5)
            computer.pullSignal(3)
            computer.shutdown()
            return
        end
        written = written + #chunk
        local progress = math.floor((written / #content) * 100)
        drawProgressBar(math.floor((screen_width - 50) / 2), math.floor(screen_height / 2), 
                      50, 2, progress, "Запись: " .. progress .. "%", 
                      "Записано: " .. math.floor(written/1024) .. "KB")
    end
    
    disk.close(file)
    
    -- Создаем файл-маркер установки
    local marker_file, err = disk.open(".temos_installed", "w")
    if marker_file then
        disk.write(marker_file, "TemOS v2.0 installed on " .. os.date())
        disk.close(marker_file)
    end
    
    -- Установка метки диска
    pcall(disk.setLabel, "TemOS_System")
    
    -- Финальный экран с анимацией
    clearScreen()
    
    -- Анимация успеха
    for i = 1, 3 do
        drawRect(1, 1, screen_width, 3, colors.success, true)
        drawText(math.floor((screen_width - unicode.len("Установка завершена!")) / 2), 2, "Установка завершена!", 0xFFFFFF, true)
        computer.pullSignal(0.3)
        drawRect(1, 1, screen_width, 3, colors.header_bg, true)
        drawText(math.floor((screen_width - unicode.len("Установка завершена!")) / 2), 2, "Установка завершена!", colors.header_text, true)
        computer.pullSignal(0.3)
    end
    
    drawRect(1, 1, screen_width, 3, colors.success, true)
    drawText(math.floor((screen_width - unicode.len("Установка завершена!")) / 2), 2, "Установка завершена!", 0xFFFFFF, true)
    
    -- Сообщения
    local messages = {
        "TemOS успешно установлена на диск " .. selected_disk.letter,
        "Система готова к использованию",
        "Перезагрузка через 5 секунд...",
        "init.lua будет запускаться автоматически"
    }
    
    for i, msg in ipairs(messages) do
        drawText(math.floor((screen_width - unicode.len(msg)) / 2), 
                math.floor(screen_height / 2) - 3 + i, msg, 
                i == 1 and colors.success or colors.text, true)
        computer.pullSignal(0.5)
    end
    
    -- Анимированный прогрессбар обратного отсчета
    for i = 5, 1, -1 do
        drawProgressBar(math.floor((screen_width - 40) / 2), math.floor(screen_height / 2) + 3, 
                      40, 2, (5-i)*20, "Перезагрузка через: " .. i .. "s", "Готово!")
        computer.pullSignal(1)
    end
    
    -- Финальный сигнал
    computer.beep(600, 0.1)
    computer.beep(800, 0.1)
    computer.beep(1000, 0.2)
    
    computer.shutdown(true)
end

-- Запуск с обработкой ошибок
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
            gpu.set(1, 1, "Ошибка установщика: " .. tostring(err))
        end
    end
    computer.beep(1000, 1)
    computer.pullSignal(3)
end
computer.shutdown()
