; ============================================================
;  MDWiki Generator
;  Walks the IR and emits Markdown files for GitHub Wiki:
;    output\Home.md       -- index of all blocks
;    output\<type>.md     -- one page per block type
;    output\_Sidebar.md   -- navigation sidebar
; ============================================================

; @[proc]
; .parent:  MDWiki
; .name:    GenerateWiki
; .desc:    Main entry. Creates output\ directory and all Wiki .md files.
; .in:      pIR -> pointer to populated DocIR
; .out:     eax -> 1 on success, 0 on error
proc GenerateWiki uses esi edi ebx, pIR
locals
    lhFile  dd 0
endl
    ; create output directory (ignore error if exists)
    invoke  CreateDirectoryA, szOutDir, 0

    ; ---- Home.md ----
    invoke  CreateFileA, szHomeMd, GENERIC_WRITE, 0, 0, \
            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    cmp     eax, INVALID_HANDLE_VALUE
    je      .Fail
    mov     [lhFile], eax

    stdcall WriteStrA, [lhFile], szHomeHeader
    stdcall WriteStrA, [lhFile], szNewline

    mov     esi, [pIR]
    mov     esi, [esi + DocIR.pFirst]
.HomeLoop:
    test    esi, esi
    jz      .HomeDone
    ; write "* [type](type)\n"
    stdcall WriteStrA,  [lhFile], szBulletLink
    stdcall WriteRawA,  [lhFile], [esi + DocBlock.pType], [esi + DocBlock.cType]
    stdcall WriteStrA,  [lhFile], szLinkMid
    stdcall WriteRawA,  [lhFile], [esi + DocBlock.pType], [esi + DocBlock.cType]
    stdcall WriteStrA,  [lhFile], szLinkEnd
    stdcall WriteStrA,  [lhFile], szNewline
    mov     esi, [esi + DocBlock.pNext]
    jmp     .HomeLoop
.HomeDone:
    invoke  CloseHandle, [lhFile]

    ; ---- one page per block ----
    mov     esi, [pIR]
    mov     esi, [esi + DocIR.pFirst]
.BlockLoop:
    test    esi, esi
    jz      .BlocksDone

    ; build "output\<type>.md" into fileBuf
    stdcall BuildFileName, fileBuf, \
            [esi + DocBlock.pType], [esi + DocBlock.cType]

    invoke  CreateFileA, fileBuf, GENERIC_WRITE, 0, 0, \
            OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    cmp     eax, INVALID_HANDLE_VALUE
    je      .NextBlock
    mov     [lhFile], eax

    ; append to end of file (allows multiple blocks per type)
    invoke  SetFilePointer, [lhFile], 0, 0, FILE_END

    ; write "## <name>\n\n"
    stdcall WriteStrA, [lhFile], szH2

    stdcall FindField, esi, szTagName, 4
    test    eax, eax
    jz      .NoName
    stdcall WriteRawA, [lhFile], [eax + DocField.pValue], [eax + DocField.cValue]
    jmp     .AfterName
.NoName:
    stdcall WriteStrA, [lhFile], szUnknown
.AfterName:
    stdcall WriteStrA, [lhFile], szNewline
    stdcall WriteStrA, [lhFile], szNewline

    ; write each field as "**tag:** value\n"
    xor     ecx, ecx
.FieldWriteLoop:
    cmp     ecx, [esi + DocBlock.fieldCount]
    jae     .FieldsDone

    imul    edx, ecx, sizeof.DocField
    lea     ebx, [esi + DocBlock.fields + edx]

    stdcall WriteStrA,  [lhFile], szBold
    stdcall WriteRawA,  [lhFile], [ebx + DocField.pName],  [ebx + DocField.cName]
    stdcall WriteStrA,  [lhFile], szBoldEnd
    stdcall WriteRawA,  [lhFile], [ebx + DocField.pValue], [ebx + DocField.cValue]
    stdcall WriteStrA,  [lhFile], szNewline

    inc     ecx
    jmp     .FieldWriteLoop
.FieldsDone:
    stdcall WriteStrA, [lhFile], szHRule
    invoke  CloseHandle, [lhFile]

.NextBlock:
    mov     esi, [esi + DocBlock.pNext]
    jmp     .BlockLoop
.BlocksDone:

    ; ---- _Sidebar.md ----
    invoke  CreateFileA, szSidebarMd, GENERIC_WRITE, 0, 0, \
            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    cmp     eax, INVALID_HANDLE_VALUE
    je      .Fail
    mov     [lhFile], eax

    stdcall WriteStrA, [lhFile], szSidebarHeader
    stdcall WriteStrA, [lhFile], szNewline

    mov     esi, [pIR]
    mov     esi, [esi + DocIR.pFirst]
.SideLoop:
    test    esi, esi
    jz      .SideDone
    stdcall WriteStrA,  [lhFile], szBulletLink
    stdcall WriteRawA,  [lhFile], [esi + DocBlock.pType], [esi + DocBlock.cType]
    stdcall WriteStrA,  [lhFile], szLinkMid
    stdcall WriteRawA,  [lhFile], [esi + DocBlock.pType], [esi + DocBlock.cType]
    stdcall WriteStrA,  [lhFile], szLinkEnd
    stdcall WriteStrA,  [lhFile], szNewline
    mov     esi, [esi + DocBlock.pNext]
    jmp     .SideLoop
.SideDone:
    invoke  CloseHandle, [lhFile]

    mov     eax, 1
    ret
.Fail:
    xor     eax, eax
    ret
endp


; @[proc]
; .parent:  MDWiki
; .name:    WriteStrA
; .desc:    Writes a null-terminated ASCII string to a file.
; .in:      hFile -> file handle; pStr -> null-terminated ASCII string
; .out:     (none)
proc WriteStrA uses ecx edi, hFile, pStr
    mov     edi, [pStr]
    xor     ecx, ecx
.Len:
    cmp     byte [edi + ecx], 0
    je      .Write
    inc     ecx
    jmp     .Len
.Write:
    test    ecx, ecx
    jz      .Done
    invoke  WriteFile, [hFile], [pStr], ecx, 0, 0
.Done:
    ret
endp


; @[proc]
; .parent:  MDWiki
; .name:    WriteRawA
; .desc:    Writes a raw byte slice (not null-terminated) to a file.
; .in:      hFile -> file handle; pBuf -> data; nBytes -> byte count
; .out:     (none)
proc WriteRawA, hFile, pBuf, nBytes
    mov     ecx, [nBytes]
    test    ecx, ecx
    jz      .Done
    invoke  WriteFile, [hFile], [pBuf], ecx, 0, 0
.Done:
    ret
endp


; @[proc]
; .parent:  MDWiki
; .name:    FindField
; .desc:    Searches a DocBlock for a field whose name matches pName.
; .in:      pBlock -> DocBlock*; pName -> ASCII string; cName -> length
; .out:     eax -> pointer to DocField, or 0 if not found
proc FindField uses esi edi ecx ebx, pBlock, pName, cName
    mov     esi, [pBlock]
    xor     ecx, ecx
.Loop:
    cmp     ecx, [esi + DocBlock.fieldCount]
    jae     .NotFound

    imul    edx, ecx, sizeof.DocField
    lea     ebx, [esi + DocBlock.fields + edx]

    mov     eax, [ebx + DocField.cName]
    cmp     eax, [cName]
    jne     .Next

    push    ecx esi edi
    mov     edi, [ebx + DocField.pName]
    mov     esi, [pName]
    mov     ecx, [cName]
    repe    cmpsb
    pop     edi esi ecx
    jne     .Next

    mov     eax, ebx
    ret
.Next:
    inc     ecx
    jmp     .Loop
.NotFound:
    xor     eax, eax
    ret
endp


; @[proc]
; .parent:  MDWiki
; .name:    BuildFileName
; .desc:    Builds "output\<type>.md\0" into pBuf.
; .in:      pBuf -> destination buffer (>=64 bytes); pType, cType -> type string
; .out:     (none)
proc BuildFileName uses esi edi ecx, pBuf, pType, cType
    mov     edi, [pBuf]
    lea     esi, [szOutDir]
.CopyDir:
    lodsb
    test    al, al
    jz      @F
    stosb
    jmp     .CopyDir
@@:
    mov     esi, [pType]
    mov     ecx, [cType]
    rep     movsb

    lea     esi, [szMdExt]
.CopyExt:
    lodsb
    stosb
    test    al, al
    jnz     .CopyExt
    ret
endp