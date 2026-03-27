format PE Console 4.0
entry WinMain

include 'win32w.inc'
include 'Macros.inc'
include 'lexer/Lexer.h.asm'

FILE_BUFFER equ 65536

section '.code' code readable executable

    include 'lexer/Lexer.asm'
    ;include 'parser/Parser.asm'

WinMain:
    invoke  GetProcessHeap
    mov     [hHeap], eax

    invoke  GetStdHandle, STD_OUTPUT_HANDLE
    mov     [hOutput], eax

    invoke  WriteConsoleW, [hOutput], msgStart, msgStart.length, 0, 0

    invoke  CreateFileW, szTestFile, GENERIC_READ, OPEN_EXISTING, 0, OPEN_EXISTING, 0, 0
    cmp     eax, INVALID_HANDLE_VALUE
    je      .Exit
    mov     [hFile], eax 

    invoke  GetFileSizeEx, [hFile], pLenght 

    invoke  CreateFileMappingW, [hFile], 0, PAGE_READONLY, 0, 0, 0
    test    eax,  eax
    jz      .Error
    mov     edi, eax 

.ReadLoop:    
    mov     eax, dword [pLenght]
    or      eax, dword [pLenght + 4]
    jz      .EndRead   
    
    mov     esi, FILE_BUFFER
    cmp     dword [pLenght + 4], 0
    jnz     @F
    cmp     dword [pLenght], esi
    jge     @F
    mov     esi, dword[pLenght]
@@:
    
    invoke  MapViewOfFile, edi, FILE_MAP_READ, dword[cPos + 4], dword[cPos], esi
    test    eax, eax
    jz      .Error
    mov     ebx, eax

    push    esi edi ebx
    mov     esi, eax            
    mov     edi, eax
    add     edi, dword [pLenght] 

.LexerCycle:
    cmp     esi, edi
    jae     .LexerEnd

    stdcall GetToken, esi       
    mov     ebx, eax            

    stdcall PrintTokenInfo, ebx 

    
    mov     ecx, [ebx + Token.cRead]
    test    ecx, ecx
    jnz     @F
    inc     ecx                
@@:
    add     esi, ecx

  
    invoke  HeapFree, [hHeap], 0, ebx
    jmp     .LexerCycle

.LexerEnd:
    pop     esi edi ebx

    invoke  WriteConsoleA, [hOutput], ebx, esi, 0, 0
    invoke  UnmapViewOfFile, ebx

    sub     dword [pLenght], esi
    sbb     dword [pLenght + 4], 0

    add     dword [cPos], esi
    adc     dword [cPos + 4], 0

    jmp     .ReadLoop

.EndRead:
   
    invoke  WriteConsoleW, [hOutput], msgDone, msgDone.length, 0, 0
    invoke  CloseHandle, [hFile]
    invoke  ExitProcess, 0
.Error:
    
    invoke  CloseHandle, [hFile]
.Exit:  
    invoke  WriteConsoleW, [hOutput], msgFileError, msgFileError.length, 0, 0
    invoke  ExitProcess, 1


proc PrintTokenInfo uses esi edi ebx, pToken
    mov     ebx, [pToken]

    invoke  WriteConsoleA, [hOutput], msgType, 9, 0, 0

    movzx   eax, byte [ebx + Token.tType]
    imul    eax, 4
    mov     esi, [TokenNames + eax]
    invoke  WriteConsoleA, [hOutput], esi, 10, 0, 0

    invoke  WriteConsoleA, [hOutput], msgLen, 7, 0, 0

    mov     eax, [ebx + Token.cRead]
    lea     edi, [charBuf]
    stdcall IntToStr, eax, edi
    invoke  WriteConsoleA, [hOutput], edi, eax, 0, 0

    invoke  WriteConsoleA, [hOutput], msgText, 10, 0, 0

    mov     esi, [ebx + Token.pStart]
    mov     ecx, [ebx + Token.cRead]
    test    ecx, ecx
    jz      .SkipText
    invoke  WriteConsoleA, [hOutput], esi, ecx, 0, 0
.SkipText:

    invoke  WriteConsoleA, [hOutput], msgQuote, 1, 0, 0
    ret
endp

proc IntToStr uses edi ebx, Val, pBuf
    mov     eax, [Val]
    mov     edi, [pBuf]
    xor     ecx, ecx
    mov     ebx, 10
.lp1:
    xor     edx, edx
    div     ebx
    add     dl, '0'
    push    edx
    inc     ecx
    test    eax, eax
    jnz     .lp1
    mov     eax, ecx 
.lp2:
    pop     edx
    mov     [edi], dl
    inc     edi
    loop    .lp2
    mov     byte [edi], 0
    ret
endp


section '.data' data readable writeable
    ustr0 szTestFile, 'test.asm'
    
    ustr0 msgStart, 'FASM AutoDocer Started...', 13, 10
    ustr0 msgDone,  'Parsing Complete.', 13, 10
    ustr0 msgFileError,  'File Error!!!', 13, 10
    
    cPos        dq 0


TokenNames:
    dd .t0, .t1, .t2, .t3, .t4, .t5, .t6, .t7, .t8, .t9
    .t0 db 'ERR       ', 0
    .t1 db 'OPEN_TYPE ', 0
    .t2 db 'CLOSE_TYPE', 0
    .t3 db 'OPEN_TAG  ', 0
    .t4 db 'IDEN      ', 0
    .t5 db 'CLOSE_TAG ', 0
    .t6 db 'FREE_LINE ', 0
    .t7 db 'SEMICOLON ', 0
    .t8 db 'TEXT_TYPE ', 0
    .t9 db 'TEXT_TAG  ', 0

msgType  db 13, 10, '[Type: ', 0
msgLen   db '] Len: ', 0
msgText  db ' | Text: "', 0
msgQuote db '"', 0
charBuf  rb 12  
    
    include 'lexer/Lexer.i.asm'

    pLenght     dq ?
    hHeap       dd ?
    hOutput     dd ?
    hFile       dd ?


section '.idata' import data readable writeable
    library kernel32, 'KERNEL32.DLL'
    
    include 'api/kernel32.inc'