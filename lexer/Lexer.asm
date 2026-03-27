; @[proc]
; .parent:  Lexer
; .name:    GetToken
; .desc:    Находит и возвращает следующий токен
; .in:      pStart -> Начало чтения символов
; .out:     eax -> Указазатель на структуру TOKEN выделенную с помощью HeapAlloc

proc GetToken uses esi, pStart
locals
    lPoint dd 0
    lState db 0 
endl
    mov     esi, [pStart]
    mov     [lPoint], esi
    mov     ecx, 1
.LoopTake:
    imul    edx, ecx, CHAR_OTHER + 1
    
    lodsb
    movzx   eax, al
    movzx   eax, byte[CharTable + eax]
    add     edx, eax
    
    movzx   ecx, byte [TokenTableMain + edx]
    test    ecx, ecx
    jz      .End

    mov     dl, [TokenStateMain + ecx]
    test    dl, dl 
    jz      .LoopTake
    mov     [lState], dl
    mov     [lPoint], esi
         
    jmp     .LoopTake

.End:
    invoke  HeapAlloc, [hHeap], 8, sizeof.Token
    
    mov     edx, [pStart]
    mov     [eax + Token.pStart], edx

    sub     edx, [lPoint]
    neg     edx
    mov     [eax + Token.cRead], edx

    mov     dl, [lState]
    mov     [eax + Token.tType], dl

    ret
endp

; @[proc]
; .parent:  Lexer
; .name:    GetTypeToken
; .desc:    Находит и возвращает следующий токен для Типа
; .in:      pStart -> Начало чтения символов
; .out:     eax -> Указазатель на структуру TOKEN выделенную с помощью HeapAlloc
proc GetTypeToken uses esi, pStart
locals
    lState db 0 
endl
    mov     esi, [pStart]
    mov     [lPoint], esi
.LoopTake: 
    mov     ecx, 1
.Check:  
    lodsb
    movzx   eax, al
    mov     al, [CharTable + eax] 
    
    test    al, al
    jz      .End

    cmp     al, 10
    je      .End 

    cmp     al, 7
    jne     .LoopTake
    mov     ecx, 2
    jmp     .Check

.End:
    sub     esi, ecx
    invoke  HeapAlloc, [hHeap], 8, sizeof.Token
    
    mov     edx, [pStart]
    mov     [eax + Token.pStart], edx

    sub     esi, edx
    mov     [eax + Token.cRead], esi

    test    esi, esi
    jz      .Err
    mov     [eax + Token.tType], TEXT_TYPE
.Err:

    ret
endp

; @[proc]
; .parent:  Lexer
; .name:    GetTagToken
; .desc:    Находит и возвращает следующий токен для Тега
; .in:      pStart -> Начало чтения символов
; .out:     eax -> Указазатель на структуру TOKEN выделенную с помощью HeapAlloc
proc GetTagToken uses esi, pStart
locals
    lPoint dd 0
    lState db 0 
endl
    mov     esi, [pStart]
    mov     [lPoint], esi
    mov     ecx, 1
.LoopTake:
    imul    edx, ecx, CHAR_OTHER + 1
    
    lodsb
    movzx   eax, al
    add     edx, [CharTable + eax]
    
    movzx   ecx, byte [TokenTableTag + edx]
    test    ecx, ecx
    jz      .End

    mov     dl, [TokenStateTag + ecx]
    test    dl, dl 
    jz      .LoopTake
    mov     [lState], dl
    mov     [lPoint], esi
         
    jmp     .LoopTake

.End:
    invoke  HeapAlloc, [hHeap], 8, sizeof.Token
    
    mov     edx, [pStart]
    mov     [eax + Token.pStart], edx

    sub     edx, [lPoint]
    neg     edx
    mov     [eax + Token.cRead], edx

    mov     dl, [lState]
    mov     [eax + Token.tType], dl

    ret   
endp