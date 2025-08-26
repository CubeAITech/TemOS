local component = require("component")
local gpu = component.gpu
local event = require("event")
local term = require("term")

local commands = {
    help = {
        description = "команды",
        execute = function()
            term.write("сегодня вам доступно\n")
            for cmd, info in pairs(commands) do
                term.write(string.format("  %-10s - %s\n", cmd, info.description))
            end
        end
    },
    time = {
        description = "время",
        execute = function()
            term.write("время: " .. os.date("%H:%M:%S") .. "\n")
        end
    },
    date = {
        description = "число седня",
        execute = function()
            term.write("сегодня: " .. os.date("%d.%m.%Y") .. "\n")
        end
    },
    clear = {
        description = "удалить все науй",
        execute = function()
            term.clear()
        end
    },
    echo = {
        description = "отправить говно текст за вас",
        execute = function(args)
            term.write("! " .. table.concat(args, " ") .. "\n")
        end
    },
    exit = {
        description = "выйти",
        execute = function()
            term.write("пока компьютер!\n")
            os.exit()
        end
    }
}

term.write("TemOS loaded\n")
term.write("введите 'help' для списка говно-команд\n")

while true do
    term.write("> ")
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
                term.write("ай бля ошибка: " .. err .. "\n")
            end
        else
            term.write("ойойой нет такой команды пошел науй: " .. command .. "\n")
            term.write("напомню 'help' введи даун\n")
        end
    end
end
