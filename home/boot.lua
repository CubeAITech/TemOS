-- TemOS - Операционная система для OpenComputers
local component = require("component")
local computer = require("computer")
local event = require("event")
local unicode = require("unicode")

-- Основные компоненты
local gpu = component.list("gpu")()
local screen = component.list("screen")()
local gpu_proxy = component.proxy(gpu)

-- Инициализация графики
if gpu and screen then
    gpu_proxy.bind(screen)
    gpu_proxy.setResolution(80, 25)
    gpu_proxy.setBackground(0x000000)
    gpu_proxy.setForeground(0xFFFFFF)
    gpu_proxy.fill(1, 1, 80, 25, " ")
end

-- Функция вывода на экран
local function printCentered(text, y)
    if gpu then
        local width = gpu_proxy.getResolution()
        local x = math.floor((width - unicode.len(text)) / 2)
        gpu_proxy.set(x, y, text)
    else
        print(text)
    end
end

-- Приветственный экран
printCentered("================================================", 2)
printCentered("            Добро пожаловать!      ", 3)
printCentered("================================================", 4)
printCentered("Операционная система TemOS", 6)
printCentered("", 7)
printCentered("", 9)
printCentered("Загрузка завершена успешно!", 11)
printCentered("Система готова к работе", 12)
printCentered("", 14)
printCentered("Для продолжения нажмите любую клавишу.", 16)

-- Основной цикл системы
local function mainLoop()
    while true do
        local e, _, _, code = event.pull("key_down")
        if e == "key_down" then
            -- Очищаем экран
            if gpu then
                gpu_proxy.fill(1, 1, 80, 25, " ")
                gpu_proxy.set(1, 1, "TemOS > Готов к работе")
                gpu_proxy.set(1, 3, "Доступные команды:")
                gpu_proxy.set(1, 4, "- help: Справка по командам")
                gpu_proxy.set(1, 5, "- apps: Запуск приложений")
                gpu_proxy.set(1, 6, "- settings: Настройки системы")
                gpu_proxy.set(1, 8, "Введите команду: _")
            else
                print("TemOS > Готов к работе")
                print("Введите команду: ")
            end
            break
        end
    end
end

-- Запуск системы
printCentered("Инициализация системы...", 18)
os.sleep(1)
mainLoop()

-- Дополнительные системные функции
local function showHelp()
    if gpu then
        gpu_proxy.fill(1, 10, 80, 15, " ")
        gpu_proxy.set(1, 10, "Доступные команды:")
        gpu_proxy.set(1, 11, "help    - Показать эту справку")
        gpu_proxy.set(1, 12, "reboot  - Перезагрузить систему")
        gpu_proxy.set(1, 13, "shutdown - Выключить компьютер")
        gpu_proxy.set(1, 14, "clear   - Очистить экран")
        gpu_proxy.set(1, 15, "apps    - Запустить меню приложений")
    else
        print("Доступные команды:")
        print("help    - Показать эту справку")
        print("reboot  - Перезагрузить систему")
        print("shutdown - Выключить компьютер")
        print("clear   - Очистить экран")
        print("apps    - Запустить меню приложений")
    end
end

-- Обработчик команд
local function handleCommand(cmd)
    if cmd == "help" then
        showHelp()
    elseif cmd == "reboot" then
        computer.shutdown(true)
    elseif cmd == "shutdown" then
        computer.shutdown()
    elseif cmd == "clear" then
        if gpu then
            gpu_proxy.fill(1, 1, 80, 25, " ")
            gpu_proxy.set(1, 1, "TemOS > ")
        else
            for i = 1, 25 do print() end
        end
    elseif cmd == "apps" then
        if gpu then
            gpu_proxy.fill(1, 10, 80, 15, " ")
            gpu_proxy.set(1, 10, "Доступные приложения:")
            gpu_proxy.set(1, 11, "1. Файловый менеджер")
            gpu_proxy.set(1, 12, "2. Текстовый редактор")
            gpu_proxy.set(1, 13, "3. Калькулятор")
            gpu_proxy.set(1, 14, "4. Игры")
        else
            print("Доступные приложения:")
            print("1. Файловый менеджер")
            print("2. Текстовый редактор")
            print("3. Калькулятор")
            print("4. Игры")
        end
    else
        if gpu then
            gpu_proxy.set(1, 20, "Неизвестная команда: " .. cmd)
        else
            print("Неизвестная команда: " .. cmd)
        end
    end
end

printCentered("Система загружена успешно!", 25)
