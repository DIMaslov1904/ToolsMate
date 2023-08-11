# ToolsMate

> Мои первые скрипты, судите строго, но по делу в телеграмме [@ToolsMate](https://t.me/ToolsMate)

ToolsMate - это сборник различных модов, упрощающий игру, а так же разработку других модификаций. К сожалению пока только в зачаточном состоянии, но всё ещё в переди!

Давайте пройдёмся по скриптам расположенных в данном репозитории

[installer](#insateller) - это база для конфигурации авто-установщика скриптов. Надеюсь зайдёт другим разработчикам и пользователям, ведь он упрощает установку модов. Разработчику достаточно указать зависимости и свой скрипт в формате: имя скрипта и ссылку на скачивания. А пользователю в свою очередь достаточно просто вставить данный скрипт в папку moonloader и всё! Установщик пройдётся по всем указанным зависимостям, установит, если они отсутсвуют, а так же установит и основной скрипт. После успешной установки он самоустраняется.

[Updater](#updater) - удобный способ добавить автообновление в свой скрипт. Скрипт позволяет проверять и обновлять все поддерживаемые его скриты как в ручном режиме, так и автоматически. О работе с ним будет сказано далее.

[AdBlock]() - простой скриптик, который позволяет убирать из чата ненужный мусор. С возможностью включать и выключать блокировку.


><br>Принимаю все вопросы, замечания и пожелания в тегераме: [@ToolsMate](https://t.me/ToolsMate)<br><br>

><br>Для всех скриптов необходимы:
[moonloader](https://www.blast.hk/threads/13305/), 
[SAMPFUNCS](https://www.blast.hk/threads/17/)<br><br>

***

### insateller
В данный момент, не реализована установка зависимостей, состоящие не из одного файла. Это будет добавлено позже. Если есть у кого желание дописать, пишите в телегу, буду рад любой помощи и критики.
Давайте посмотрим, как это выглядит сейчас:
```Lua
local packages = {
    {
        name = 'ToolsMate[Updater].lua', -- путь до файла
		url = 'https://raw.githubuse...' -- ссылка для его скачивания
    },
    ...
}
```
В поле ```name``` мы указывает путь до файла относительно папки moonloader. Можно писать свои библиотеки в отдельных папках, но главный исполняющий файл должен быть в корне папки moonloader! Кто не знает, как получать ссылки на файлы в github, пишите мне в телеграм, расскажу, покажу. Пример:
```Lua
local packages = {
    {
        name = 'ToolsMate/ToolsMate[Updater].lua',
		url = 'ссылка'
    },
    {
        name = 'ToolsMate.lua',
		url = 'ссылка'
    }
}
```
В дальнейшем система будет упрощена для установки множества файлов.<br>
Тут мы устанавливаем скрипт, модуль, или что либо в отдельную папку. А также главный исполняемый файл, в котором обращаемся к вышеуказанному файлу. Возможно у кого-то возникнет вопрос зачем разделать скрипт? Да, если ваш скрипт не большой, выполняет простую функцию и не намерен развиваться в дальнейшем, то можно всё делать и в одном файле. Но разделение скрипта на составные части позволяет упростить разработку, поддуржку и читаемость кода в разы.

> В планах: добавить загрузку библиотк состоязих из множества файлов

***

### Updater
По умолчанию скрипт при заходе в игру, через 2 минуты проходит по всех скриптам и собирает название, версии и необходимые параметры указанные ниже. Далее запрашивает файлы версий. Далее скачивает при обновлении версии и перезагружает скрипт.

В данный момент реализованы данные функции для упраления
+ ```/updater check``` - проверить все скрипты
+ ```/updater check script name``` - проверить только "script name" (допустимы пробелы в названии скриптов)
+ ```/updater get script name``` - обновить "script name" (допустимы пробелы в названии скриптов)
+ ```/updater autoCheck``` - включает и отключает авто-проверку при запуски игры
+ ```/updater autoDownload``` - включает и отключает авто-скачивание после проверки. Будут выведены библиотеки нуждающиеся в обновлении и предложена команда для их обновления

При желании можете изменять локализацию и менять команды. Посмотрев код, поймете, где можно это изменить (Лучше так не делать, а написать мне, если будет уместо - добавлю, иначе при обновлении всё сбросится)


Для разработчика! Чтобы скрипт коректно работал с вашими скриптами необходимо указать:
+ ```script_name('Название скрипта')```
+ ```script_version("1.0.0")``` - для работы необходим только строчный номер версии.
Версия может состоять из любова количества частей разделенных точкой, не более 3 символов в части! Допустимы версии например такого вида 999.999. Надеюсь вам хватит этих 999 масштабных версий
+ ```EXPORTS.URL_CHECK_UPDATE = 'ссылка'``` - ссылка на файл содержащий версию одного или нескольких скриптов. Формат файла будет чуть ниже
+ ```EXPORTS.URL_GET_UPDATE = 'ссылка'``` - ссылка на сам скрипт. Если ее не добавить, скрипт сможет сверить версию, и вывести уведомление о новой версии в чат
+ ```EXPORTS.TAG_ADDONS = 'Тэг'``` - [опционально] это общее название для нескольких ваших скриптов. Если указан тег, то будет скачиваться только один файл с версиями и из него будут браться версии для всех ваших версий. Далее будет формат файла.
+ ```EXPORTS.NO_AUTO_UPDATE = true``` - [опционально] указывает, на только ручную обновление скрипта. Т.е. он не будет автоматически установлен при проверке, а бедет предложена команда для его установки. Мне он был нужен для самого этого скрипта, чтобы он не прервал обновление других библиотек, начав обновлять себя.

> В планах:<br>
добавить загрузку библиотк состоязих из множества файлов<br>
добавить ui интерфейс для управления и отображения всез скриптов и их версий

***

### AdBlock
В данный момент реализованы данные функции для упраления
+ ```/adb``` - включает и отключает блокировку указанных сообщений

В коде:
```Lua
local toggle = true
```
Флаг позволяющий включать или не включать при запуски игры данный скрипт
```Lua
local messages = {
  'Объявление:',
  'Редакция News',
  ...
}
```
Добавляем в "таблицу" необходимые фразы, при появлении которых, сообщение будет не выведено в чат. 

> В планах: добавить ui интерфейс для управления и добавления фраз не выходя из игры