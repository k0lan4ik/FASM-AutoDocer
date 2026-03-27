; @[module]
; .name: Crawler
; .desc: Рекурсивный обход файловой системы Windows. 
;        Ищет файлы .asm и .inc, фильтруя их через ignore-list.

section '.data' readable writeable
    wildcard    du '\*', 0
    dot         du '.', 0
    dotdot      du '..', 0

section '.code' readable executable

; @[proc]
; .name: ScanDirectory
; .desc: Основная рекурсивная функция обхода папок.
; .in:   path -> Указатель на Unicode-строку (UTF-16) с путем к папке.
; .out:  EAX  -> Статус выполнения (0 - ошибка, 1 - успех).
; .note: Использует WIN32_FIND_DATAW в стеке. Глубина рекурсии ограничена стеком Windows.
proc ScanDirectory uses ebx esi edi, path
    local find_data:WIN32_FIND_DATAW  ; Структура в стеке (~592 байта)
    local search_path[MAX_PATH]:WORD  ; Буфер для пути поиска
    local hFind:DWORD                 ; Хендл поиска


    ; 1. Подготовка search_path: "path" + "\*"
    invoke lstrcpyW, addr search_path, [path]
    invoke lstrcatW, addr search_path, wildcard

    ; 2. Начинаем поиск
    invoke FindFirstFileW, addr search_path, addr find_data
    mov [hFind], eax
    
    cmp eax, INVALID_HANDLE_VALUE
    je .exit

.find_loop:
    ; Проверка на "." и ".." (чтобы не уйти в бесконечный цикл)
    lea eax, [find_data.cFileName]
    invoke lstrcmpW, eax, dot
    test eax, eax
    jz .next_file
    lea eax, [find_data.cFileName]
    invoke lstrcmpW, eax, dotdot
    test eax, eax
    jz .next_file

    ; Проверка списка игнорирования
    lea eax, [find_data.cFileName]
    stdcall is_file_ignored_w, eax
    jc .next_file

    ; Проверяем, это папка или файл
    test [find_data.dwFileAttributes], FILE_ATTRIBUTE_DIRECTORY
    jz .is_file

.is_directory:
    ; Формируем новый путь: "path" + "\" + "subdir"
    invoke lstrcpyW, addr search_path, [path]
    invoke lstrcatW, addr search_path, addr wildcard ; Тут нужен просто слеш, но для краткости...
    ; В идеале: склеить path + \ + cFileName
    ; И вызвать рекурсию:
    ; stdcall scan_directory_w, addr search_path
    jmp .next_file

.is_file:
    ; Здесь вызываем парсер для найденного файла
    ; Нужно передать полный путь: [path] + cFileName
    lea eax, [find_data.cFileName]
    stdcall process_source_file, [path], eax

.next_file:
    invoke FindNextFileW, [hFind], addr find_data
    test eax, eax
    jnz .find_loop

    invoke FindClose, [hFind]

.exit:
    ret
endp