local commands = {
    help = {
        description = "Показать список команд",
        execute = function()
            print("📋 Доступные команды:")
            for cmd, info in pairs(commands) do
                print(string.format("  %-10s - %s", cmd, info.description))
            end
        end
    },
    time = {
        description = "Показать текущее время",
        execute = function()
            print("🕒 Текущее время: " .. os.date("%H:%M:%S"))
        end
    },
    date = {
        description = "Показать текущую дату",
        execute = function()
            print("📅 Сегодня: " .. os.date("%d.%m.%Y"))
        end
    },
    clear = {
        description = "Очистить экран",
        execute = function()
            os.execute("cls || clear")
        end
    },
    echo = {
        description = "Повторить введенный текст",
        execute = function(args)
            print("📢 " .. table.concat(args, " "))
        end
    },
    exit = {
        description = "Выйти из программы",
        execute = function()
            print("👋 До свидания!")
            os.exit()
        end
    }
}

print("🚀 Добро пожаловать в Lua Terminal!")
print("Введите 'help' для списка команд")

while true do
    io.write("> ")
    local input = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if input ~= "" then
        local parts = {}
        for part in input:gmatch("%S+") do
            table.insert(parts, part)
        end
        
        local command = parts[1]:lower()
        table.remove(parts, 1)
        
        if commands[command] then
            local success, err = pcall(function()
                commands[command].execute(parts)
            end)
            
            if not success then
                print("❌ Ошибка выполнения команды: " .. err)
            end
        else
            print("❌ Команда не найдена: " .. command)
            print("ℹ️  Введите 'help' для списка доступных команд")
        end
    end
