format PE Console 4.0
entry WinMain

include 'win32w.inc'
include 'Macros.inc'
include 'lexer/Lexer.h.asm'
include 'parser/Parser.h.asm'

FILE_BUFFER equ 65536

section '.code' code readable executable

    include 'lexer/Lexer.asm'
    include 'parser/Parser.asm'
    include 'generators/MDWiki.asm'

WinMain:
    invoke  GetProcessHeap
    mov     [hHeap], eax

    invoke  GetStdHandle, STD_OUTPUT_HANDLE
    mov     [hOutput], eax

    invoke  WriteConsoleW, [hOutput], msgStart, msgStart.length, 0, 0

    ; --- open input file ---
    invoke  CreateFileW, szTestFile, GENERIC_READ, FILE_SHARE_READ, 0, \
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    cmp     eax, INVALID_HANDLE_VALUE
    je      .FileError
    mov     [hFile], eax

    invoke  GetFileSizeEx, [hFile], pLenght

    ; --- map entire file into memory ---
    invoke  CreateFileMappingW, [hFile], 0, PAGE_READONLY, 0, 0, 0
    test    eax, eax
    jz      .MapError
    mov     [hMapping], eax

    invoke  MapViewOfFile, [hMapping], FILE_MAP_READ, 0, 0, 0
    test    eax, eax
    jz      .MapError
    mov     [pView], eax

    ; --- parse ---
    invoke  WriteConsoleW, [hOutput], msgParsing, msgParsing.length, 0, 0

    lea     eax, [docIR]
    stdcall ParseDocument, [pView], dword [pLenght], eax
    test    eax, eax
    jz      .ParseFail

    lea     eax, [docIR]

; показать сколько блоков нашли
mov     eax, [docIR + DocIR.blockCount]
lea     edi, [charBuf]
stdcall IntToStr, eax, edi
invoke  WriteConsoleA, [hOutput], charBuf, 10, 0, 0

    ; --- generate wiki ---
    invoke  WriteConsoleW, [hOutput], msgGenerating, msgGenerating.length, 0, 0

    lea     eax, [docIR]
    stdcall GenerateWiki, eax
    test    eax, eax
    jz      .GenFail

    invoke  WriteConsoleW, [hOutput], msgDone, msgDone.length, 0, 0
    jmp     .Cleanup

.GenFail:
    invoke  WriteConsoleW, [hOutput], msgGenError, msgGenError.length, 0, 0
    jmp     .Cleanup

.ParseFail:
    invoke  WriteConsoleW, [hOutput], msgParseError, msgParseError.length, 0, 0
    jmp     .Cleanup

.MapError:
    invoke  CloseHandle, [hFile]
    jmp     .Exit

.FileError:
    invoke  WriteConsoleW, [hOutput], msgFileError, msgFileError.length, 0, 0
    invoke  ExitProcess, 1

.Cleanup:
    lea     eax, [docIR]
    stdcall FreeIR, eax
    invoke  UnmapViewOfFile, [pView]
    invoke  CloseHandle, [hMapping]
    invoke  CloseHandle, [hFile]
.Exit:
    invoke  ExitProcess, 0


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

proc WriteCStrA uses ecx edi, pStr
    mov     edi, [pStr]
    xor     ecx, ecx
  .len:
    cmp     byte [edi + ecx], 0
    je      .write
    inc     ecx
    jmp     .len
  .write:
    test    ecx, ecx
    jz      .done
    invoke  WriteConsoleA, [hOutput], [pStr], ecx, 0, 0
  .done:
    ret
endp

proc DumpToken uses eax ebx ecx edx esi, pTok
    mov     esi, [pTok]
    test    esi, esi
    jz      .done

    stdcall WriteCStrA, szTokPrefix

    movzx   eax, byte [esi + Token.tType]
    cmp     eax, TOKEN_OPEN_TYPE
    je      .t_open_type
    cmp     eax, TOKEN_CLOSE_TYPE
    je      .t_close_type
    cmp     eax, TOKEN_OPEN_TAG
    je      .t_open_tag
    cmp     eax, TOKEN_IDEN
    je      .t_iden
    cmp     eax, TOKEN_CLOSE_TAG
    je      .t_close_tag
    cmp     eax, TOKEN_FREE_LINE
    je      .t_free_line
    cmp     eax, TOKEN_SEM
    je      .t_sem
    cmp     eax, TEXT_TYPE
    je      .t_text_type
    cmp     eax, TEXT_TAG
    je      .t_text_tag
    jmp     .t_err

  .t_open_type:  stdcall WriteCStrA, szTokOpenType   ; "@["
                 jmp .after_type
  .t_close_type: stdcall WriteCStrA, szTokCloseType  ; "]"
                 jmp .after_type
  .t_open_tag:   stdcall WriteCStrA, szTokOpenTag    ; "."
                 jmp .after_type
  .t_iden:       stdcall WriteCStrA, szTokIden
                 jmp .after_type
  .t_close_tag:  stdcall WriteCStrA, szTokCloseTag   ; ":"
                 jmp .after_type
  .t_free_line:  stdcall WriteCStrA, szTokFreeLine
                 jmp .after_type
  .t_sem:        stdcall WriteCStrA, szTokSem
                 jmp .after_type
  .t_text_type:  stdcall WriteCStrA, szTokTextType
                 jmp .after_type
  .t_text_tag:   stdcall WriteCStrA, szTokTextTag
                 jmp .after_type
  .t_err:        stdcall WriteCStrA, szTokErr

  .after_type:
    stdcall WriteCStrA, szTokMid

    mov     eax, [esi + Token.cRead]
    lea     edx, [charBuf]
    stdcall IntToStr, eax, edx
    invoke  WriteConsoleA, [hOutput], charBuf, eax, 0, 0

    stdcall WriteCStrA, szTokLexeme

    mov     ecx, [esi + Token.cRead]
    test    ecx, ecx
    jz      .empty
    invoke  WriteConsoleA, [hOutput], [esi + Token.pStart], ecx, 0, 0
    jmp     .newline

  .empty:
    stdcall WriteCStrA, szTokEmpty

  .newline:
    stdcall WriteCStrA, szCRLF
  .done:
    ret
endp


section '.data' data readable writeable
    szTokPrefix     db '[TOK] ',0
    szTokMid        db ' len=',0
    szTokLexeme     db ' text="',0
    szTokEmpty      db '<empty>',0
    szCRLF          db '"',13,10,0

    szTokErr        db 'ERR',0
    szTokOpenType   db 'OPEN_TYPE',0
    szTokCloseType  db 'CLOSE_TYPE',0
    szTokOpenTag    db 'OPEN_TAG',0
    szTokIden       db 'IDEN',0
    szTokCloseTag   db 'CLOSE_TAG',0
    szTokFreeLine   db 'FREE_LINE',0
    szTokSem        db 'SEM',0
    szTokTextType   db 'TEXT_TYPE',0
    szTokTextTag    db 'TEXT_TAG',0
    ustr0 szTestFile,    'test.asm'
    ustr0 msgStart,      'FASM AutoDocer Started...', 13, 10
    ustr0 msgParsing,    'Parsing...', 13, 10
    ustr0 msgGenerating, 'Generating Wiki...', 13, 10
    ustr0 msgDone,       'Done! Wiki written to output\', 13, 10
    ustr0 msgFileError,  'File Error!', 13, 10
    ustr0 msgParseError, 'Parse Error!', 13, 10
    ustr0 msgGenError,   'Generator Error!', 13, 10

    cPos    dq 0
    charBuf rb 12

    ; generator string constants
    szOutDir        db 'output\', 0
    szHomeMd        db 'output\Home.md', 0
    szSidebarMd     db 'output\_Sidebar.md', 0
    szMdExt         db '.md', 0
    szHomeHeader    db '# Documentation Index', 13, 10, 0
    szSidebarHeader db '## Contents', 13, 10, 0
    szH2            db '## ', 0
    szBulletLink    db '* [', 0
    szLinkMid       db '](',  0
    szLinkEnd       db ')',   0
    szBold          db '**',  0
    szBoldEnd       db ':** ', 0
    szHRule         db 13, 10, '---', 13, 10, 0
    szNewline       db 13, 10, 0
    szUnknown       db '(unknown)', 0
    szTagName       db 'name'

    fileBuf         rb 256   ; buffer for BuildFileName

    include 'lexer/Lexer.i.asm'
    include 'parser/Parser.i.asm'

    pLenght     dq ?
    hHeap       dd ?
    hOutput     dd ?
    hFile       dd ?
    hMapping    dd ?
    pView       dd ?

    docIR       DocIR        ; IR root node (zeroed by BSS rules)


section '.idata' import data readable writeable
    library kernel32, 'KERNEL32.DLL'

    include 'api/kernel32.inc'