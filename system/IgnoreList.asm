; @[module]
; .name: IgnoreList
; .desc: Управление списком исключений. Поддерживает простую структуру 
;        текстового файла, где каждый формат/имя на новой строке.

section '.code' readable executable

; @[proc]
; .name: is_file_ignored_w
; .desc: Сравнивает имя файла с загруженным в память списком игнорирования.
; .in:   filename_w -> Указатель на Unicode-имя файла для проверки.
; .out:  CF (Carry Flag) -> 1 (Игнорировать), 0 (Обработать).
proc LoadIgnoreList uses ebx esi edi, filename
    
    invoke  CreateFile, [filename], GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0
    cmp     eax, INVALID_HANDLE_VALUE
    je      .Exit
    mov     ebx, eax 

    invoke GetFileSize, ebx, 0
    mov ecx, eax 
    
    invoke HeapAlloc, [hHeap], HEAP_ZERO_MEMORY, ecx
    mov [gnore_data_ptr], eax
    

    invoke ReadFile, ebx, [ignore_data_ptr], ecx, bytes_read, 0
    invoke CloseHandle, ebx

    ; Инициализируем указатели для парсинга
    mov esi, [ignore_data_ptr]
    mov edx, [bytes_read]
    add edx, esi      ; EDX = граница буфера

    ; Выделяем массив под указатели (напр. 256 строк)
    invoke HeapAlloc, [hHeap], HEAP_ZERO_MEMORY, 256*4
    mov [ignore_p_array], eax
    mov edi, eax
    
.parse_loop:
    cmp esi, edx
    jae .done
    
    ; Сохраняем начало текущей строки в массив
    mov [edi], esi
    add edi, 4
    inc [ignore_count]

.find_end_of_line:
    lodsb
    cmp al, 10        ; Newline (LF)
    je .terminate_str
    cmp al, 13        ; Carriage Return (CR)
    je .terminate_str
    cmp esi, edx
    jb .find_end_of_line
    jmp .done

.terminate_str:
    mov byte [esi-1], 0 ; Ставим NULL-терминатор вместо переноса
.skip_line_endings:     ; Пропускаем оставшиеся \r или \n (для \r\n)
    cmp esi, edx
    jae .done
    mov al, [esi]
    cmp al, 10
    je .next_char
    cmp al, 13
    jne .ParseLoop
.NextChar:
    inc esi
    jmp .SkipLineEndings

.Done:
.Exit:
    ret
endp