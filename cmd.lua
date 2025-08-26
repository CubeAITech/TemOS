local commands = {
    help = {
        description = "команды",
        execute = function()
            print("сегодня вам доступно")
            for cmd, info in pairs(commands) do
                print(string.format("  %-10s - %s", cmd, info.description))
            end
        end
    },
    time = {
        description = "время",
        execute = function()
            print("время: " .. os.date("%H:%M:%S"))
        end
    },
    date = {
        description = "число седня",
        execute = function()
            print("сегодня: " .. os.date("%d.%m.%Y"))
        end
    },
    clear = {
        description = "удалить все науй",
        execute = function()
            os.execute("cls || clear")
        end
    },
    echo = {
        description = "отправить говно текст за вас",
        execute = function(args)
            print("! " .. table.concat(args, " "))
        end
    },
    exit = {
        description = "выйти",
        execute = function()
            print("пока компьютер!")
            os.shutdown()
        end
    }
}

print("TemOS loaded")
print("введите 'help' для списка говно-команд")

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
                print("ай бля ошибка: " .. err)
            end
        else
            print("ойойой нет такой команды пошел науй: " .. command)
            print("напомню 'help' введи даун")
        end
    end
end
