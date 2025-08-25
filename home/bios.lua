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
    text = 0xFFFFFF,
    accent = 0x0078D7,
    button = 0x0078D7,
    button_hover = 0x106EBE,
    button_text = 0xFFFFFF,
    disk_normal = 0x3C3C3C,
    disk_selected = 0x0078D7,
    disk_text = 0xFFFFFF,
    error = 0xFF0000
}

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
    
    -- Функции отрисовки
    local function clearScreen()
        gpu.setBackground(colors.background)
        gpu.setForeground(colors.text)
        gpu.fill(1, 1, screen_width, screen_height, " ")
    end
    
    local function drawBox(x, y, width, height, bgColor, text, textColor)
        gpu.setBackground(bgColor)
        gpu.fill(x, y, width, height, " ")
        if text then
            gpu.setForeground(textColor or colors.text)
            local textX = math.floor(x + (width - unicode.len(text)) / 2)
            local textY = math.floor(y + height / 2)
            gpu.set(textX, textY, text)
        end
    end
    
    local function showMessage(message)
        clearScreen()
        gpu.setForeground(colors.text)
        local x = math.floor((screen_width - unicode.len(message)) / 2)
        local y = math.floor(screen_height / 2)
        gpu.set(x, y, message)
    end
    
    -- Показываем начальное сообщение
    showMessage("Загрузка установщика TemOS...")
    computer.pullSignal(1)
    
    -- Поиск дисков
    local disks = {}
    for address, type in component.list("filesystem") do
        if type == "filesystem" then
            local fs = component.proxy(address)
            local label = fs.getLabel() or "Без названия"
            
            if label ~= "tmpfs" and not fs.isReadOnly() then
                table.insert(disks, {
                    address = address,
                    label = label,
                    proxy = fs
                })
            end
        end
    end
    
    if #disks == 0 then
        showMessage("Нет доступных дисков для установки")
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    -- Показываем выбор диска
    clearScreen()
    drawBox(1, 1, screen_width, 3, colors.header_bg, "TemOS - Выбор диска", colors.text)
    
    gpu.setForeground(colors.text)
    gpu.set(2, 5, "Выберите диск для установки:")
    
    local selected_disk = nil
    local disk_items = {}
    
    -- Рисуем список дисков
    for i, disk in ipairs(disks) do
        local y = 7 + (i-1)*2
        local bg = colors.disk_normal
        disk_items[i] = {y = y, disk = disk}
        drawBox(2, y, screen_width - 2, 1, bg, disk.label .. " (" .. disk.address:sub(1,6) .. ")", colors.text)
    end
    
    -- Рисуем кнопки
    local install_y = 7 + #disks * 2 + 2
    drawBox(2, install_y, 20, 3, colors.button, "УСТАНОВИТЬ", colors.button_text)
    
    local cancel_y = install_y + 4
    drawBox(2, cancel_y, 20, 3, colors.disk_normal, "ОТМЕНА", colors.text)
    
    -- Ждем выбора пользователя
    while true do
        local signal = {computer.pullSignal()}
        if signal[1] == "touch" then
            local x, y = signal[3], signal[4]
            
            -- Проверка выбора диска
            for i, item in ipairs(disk_items) do
                if y == item.y then
                    selected_disk = item.disk
                    -- Подсвечиваем выбранный диск
                    for j, item2 in ipairs(disk_items) do
                        local bg = (j == i) and colors.disk_selected or colors.disk_normal
                        drawBox(2, item2.y, screen_width - 2, 1, bg, item2.disk.label, colors.text)
                    end
                    break
                end
            end
            
            -- Проверка кнопки установки
            if selected_disk and y >= install_y and y < install_y + 3 and x >= 2 and x < 22 then
                break
            end
            
            -- Проверка кнопки отмены
            if y >= cancel_y and y < cancel_y + 3 and x >= 2 and x < 22 then
                computer.shutdown()
                return
            end
        end
    end
    
    -- Процесс установки
    showMessage("Проверка сети...")
    
    -- Проверяем наличие интернета
    local internet_addr = component.list("internet")()
    if not internet_addr then
        showMessage("Ошибка: Требуется сетевая карта")
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    showMessage("Загрузка системы...")
    
    -- Загружаем систему
    local internet = component.proxy(internet_addr)
    local handle, err = internet.request("https://raw.githubusercontent.com/CubeAITech/TemOS/main/home/init.lua")
    if not handle then
        showMessage("Ошибка загрузки: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    local content = ""
    while true do
        local chunk = handle.read()
        if not chunk then break end
        content = content .. chunk
    end
    handle.close()
    
    if content == "" then
        showMessage("Ошибка: Пустой файл")
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    showMessage("Запись на диск...")
    
    -- Записываем на диск
    local disk = selected_disk.proxy
    local file, err = disk.open("init.lua", "w")
    if not file then
        showMessage("Ошибка записи: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    local success, err = disk.write(file, content)
    if not success then
        disk.close(file)
        showMessage("Ошибка записи: " .. tostring(err))
        computer.pullSignal(3)
        computer.shutdown()
        return
    end
    
    disk.close(file)
    
    -- Пытаемся установить метку
    pcall(disk.setLabel, "delay")
    
    showMessage("Установка завершена!")
    computer.pullSignal(2)
    computer.shutdown(true)
end

-- Запуск с обработкой ошибок
local ok, err = pcall(main)
if not ok then
    -- Минимальный вывод ошибки
    local gpu_addr = component.list("gpu")()
    if gpu_addr then
        local gpu = component.proxy(gpu_addr)
        local screen_addr = component.list("screen")()
        if screen_addr and gpu.bind(screen_addr) then
            gpu.setResolution(gpu.maxResolution())
            gpu.setBackground(0x000000)
            gpu.setForeground(0xFFFFFF)
            gpu.fill(1, 1, gpu.getResolution(), " ")
            gpu.set(1, 1, "Ошибка: " .. tostring(err))
        end
    end
    computer.pullSignal(3)
end
computer.shutdown()
