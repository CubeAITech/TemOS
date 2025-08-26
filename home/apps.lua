-- TemOS Applications Manager
local apps = {}

-- Список приложений
apps.list = {
    {
        name = "Файловый менеджер",
        description = "Управление файлами и папками",
        command = "filemanager"
    },
    {
        name = "Текстовый редактор",
        description = "Редактирование текстовых файлов",
        command = "editor"
    },
    {
        name = "Калькулятор",
        description = "Простой калькулятор",
        command = "calculator"
    },
    {
        name = "Игры",
        description = "Коллекция игр",
        command = "games"
    }
}

-- Запуск приложения
function apps.run(appName)
    for _, app in ipairs(apps.list) do
        if app.command == appName then
            return true
        end
    end
    return false
end

-- Получение списка приложений
function apps.getList()
    return apps.list
end

return apps
