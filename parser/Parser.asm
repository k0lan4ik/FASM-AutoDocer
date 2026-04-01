; ============================================================
;  Parser -- LL(1) recursive-descent
;  DEBUG BUILD: token dump + AST dump enabled
; ============================================================

; -----------------------------------------------------------
; proc ParseDocument
; -----------------------------------------------------------
; @[proc]
; .parent:  Parser
; .name:    ParseDocument
; .desc:    Entry point. Scans the whole file mapping and builds the IR.
; .in:      pBuf   -> start of mapped file bytes
;           nBytes -> byte count of mapped region
;           pIR    -> pointer to zeroed DocIR structure
; .out:     eax    -> 1 on success, 0 on allocation failure
proc ParseDocument uses esi edi ebx, pBuf, nBytes, pIR
locals
    lEnd    dd 0
endl
    mov     esi, [pBuf]
    mov     eax, [pBuf]
    add     eax, [nBytes]
    mov     [lEnd], eax

    mov     edi, [pIR]
    mov     dword [edi + DocIR.pFirst],     0
    mov     dword [edi + DocIR.blockCount], 0

    invoke  WriteConsoleA, [hOutput], szDbgDocStart, szDbgDocStart.len, 0, 0

.Loop:
    cmp     esi, [lEnd]
    jae     .Done

    stdcall GetToken, esi           ; lookahead
    tok_dbg                         ; <-- dump lookahead token
    test    eax, eax
     jz      .Skip1        
    
    movzx   ecx, byte [eax + Token.tType]
    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    cmp     ecx, TOKEN_OPEN_TYPE
    jne     .AnyDoc

    ; Document -> Block Document
    invoke  HeapFree, [hHeap], 0, eax
    stdcall ParseBlock, esi, [lEnd], [pIR]
    test    eax, eax
    jz      .Fail
    mov     esi, [lParsePos]
    jmp     .Loop

.AnyDoc:
    add     esi, edx
    invoke  HeapFree, [hHeap], 0, eax
    jmp     .Loop

.Skip1:                   
    inc     esi            
    jmp     .Loop

.Done:  mov eax, 1
        ret
.Fail:  xor eax, eax
        ret
endp


; -----------------------------------------------------------
; proc ParseBlock
;   Block -> TOKEN_OPEN_TYPE TypeID TOKEN_CLOSE_TYPE Body
; -----------------------------------------------------------
proc ParseBlock uses esi edi ebx, pPos, pEnd, pIR
locals
    lBlock  dd 0
endl
    mov     esi, [pPos]

    invoke  WriteConsoleA, [hOutput], szDbgBlock, szDbgBlock.len, 0, 0

    ; consume TOKEN_OPEN_TYPE
    stdcall GetToken, esi
    tok_dbg
    test eax, eax
    jz .Fail
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    add esi, edx
    invoke HeapFree, [hHeap], 0, eax

    ; TypeID -> TEXT_TYPE
    stdcall GetTypeToken, esi
    tok_dbg
    test eax, eax
    jz .Fail
    movzx ecx, byte [eax + Token.tType]
    cmp ecx, TEXT_TYPE
    jne .FreeTypeFail

    push dword [eax + Token.pStart]
    push dword [eax + Token.cRead]
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    add esi, edx
    invoke HeapFree, [hHeap], 0, eax

    ; consume TOKEN_CLOSE_TYPE
    stdcall GetToken, esi
    tok_dbg
    test eax, eax
    jz .PopFail
    movzx ecx, byte [eax + Token.tType]
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    invoke HeapFree, [hHeap], 0, eax
    cmp ecx, TOKEN_CLOSE_TYPE
    jne .PopFail
    add esi, edx

    invoke HeapAlloc, [hHeap], HEAP_ZERO_MEMORY, sizeof.DocBlock
    test eax, eax
    jz .PopFail
    mov [lBlock], eax
    pop dword [eax + DocBlock.cType]
    pop dword [eax + DocBlock.pType]

    ; Body -> Field Body | e
    stdcall ParseBody, esi, [pEnd], [lBlock]
    test eax, eax
    jz .BlockFail
    mov esi, [lParsePos]

    ; attach to IR
    mov ebx, [lBlock]
    mov edi, [pIR]
    mov eax, [edi + DocIR.pFirst]
    test eax, eax
    jnz .WalkTail
    mov [edi + DocIR.pFirst], ebx
    jmp .Attached
.WalkTail:
    mov ecx, [eax + DocBlock.pNext]
    test ecx, ecx
    jz .FoundTail
    mov eax, ecx
    jmp .WalkTail
.FoundTail:
    mov [eax + DocBlock.pNext], ebx
.Attached:
    inc dword [edi + DocIR.blockCount]
    mov [lParsePos], esi
    mov eax, 1
    jmp .EndProc

.BlockFail:
    invoke HeapFree, [hHeap], 0, [lBlock]
.PopFail:
    pop eax
    pop eax
.Fail:
    xor eax, eax
    jmp .EndProc
.FreeTypeFail:
    invoke HeapFree, [hHeap], 0, eax
    xor eax, eax
.EndProc:
    ret
endp


; -----------------------------------------------------------
; proc ParseBody
;   Body -> Field Body | e
; -----------------------------------------------------------
proc ParseBody uses esi, pPos, pEnd, pBlock
    mov esi, [pPos]

    invoke  WriteConsoleA, [hOutput], szDbgBody, szDbgBody.len, 0, 0

.Loop:
    cmp esi, [pEnd]
    jae .Done
    stdcall GetToken, esi
    tok_dbg
    test eax, eax
    jz .Done
    movzx ecx, byte [eax + Token.tType]
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    cmp ecx, TOKEN_OPEN_TAG
    je .DoField
    invoke HeapFree, [hHeap], 0, eax    ; Body -> e
    jmp .Done
.DoField:
    invoke HeapFree, [hHeap], 0, eax
    stdcall ParseField, esi, [pEnd], [pBlock]
    test eax, eax
    jz .Fail
    mov esi, [lParsePos]
    jmp .Loop
.Done:
    mov [lParsePos], esi
    mov eax, 1
    jmp .EndProc
.Fail:
    xor eax, eax
.EndProc:
    ret
endp


; -----------------------------------------------------------
; proc ParseField
;   Field -> TOKEN_OPEN_TAG TagName TOKEN_CLOSE_TAG TagValue
; -----------------------------------------------------------
proc ParseField uses esi edi ebx, pPos, pEnd, pBlock
locals
    lIdenTok dd 0
endl
    mov esi, [pPos]

    invoke  WriteConsoleA, [hOutput], szDbgField, szDbgField.len, 0, 0

    ; consume TOKEN_OPEN_TAG
    stdcall GetToken, esi
    tok_dbg
    test eax, eax
    jz .Fail
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    add esi, edx
    invoke HeapFree, [hHeap], 0, eax

    ; TagName -> TOKEN_IDEN
    stdcall GetToken, esi
    tok_dbg
    test eax, eax
    jz .Fail
    movzx ecx, byte [eax + Token.tType]
    cmp ecx, TOKEN_IDEN
    jne .FreeIdenFail
    mov [lIdenTok], eax
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    add esi, edx

    ; consume TOKEN_CLOSE_TAG
    stdcall GetToken, esi
    tok_dbg
    test eax, eax
    jz .FreeIden
    movzx ecx, byte [eax + Token.tType]
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    invoke HeapFree, [hHeap], 0, eax
    cmp ecx, TOKEN_CLOSE_TAG
    jne .FreeIden
    add esi, edx

    ; TagValue
    stdcall ParseTagValue, esi, [pEnd]
    test eax, eax
    jz .FreeIden
    mov esi, [lParsePos]

    ; store field
    mov ebx, [pBlock]
    mov edi, [ebx + DocBlock.fieldCount]
    cmp edi, MAX_FIELDS
    jge .SkipStore
    imul edi, sizeof.DocField
    lea edi, [ebx + DocBlock.fields + edi]
    mov eax, [lIdenTok]
    mov edx, [eax + Token.pStart]
    mov [edi + DocField.pName],  edx
    mov edx, [eax + Token.cRead]
    mov [edi + DocField.cName],  edx
    mov edx, [lTagValStart]
    mov [edi + DocField.pValue], edx
    mov edx, [lTagValLen]
    mov [edi + DocField.cValue], edx
    inc dword [ebx + DocBlock.fieldCount]
.SkipStore:
    invoke HeapFree, [hHeap], 0, [lIdenTok]
    mov [lParsePos], esi
    mov eax, 1
    ret

.FreeIden:
    invoke HeapFree, [hHeap], 0, [lIdenTok]
.Fail:
    xor eax, eax
    ret
.FreeIdenFail:
    invoke HeapFree, [hHeap], 0, eax
    xor eax, eax
    ret
endp


; -----------------------------------------------------------
; proc ParseTagValue
;   TagValue -> TEXT_TAG TagValue | TOKEN_FREE_LINE TagValue | e
; -----------------------------------------------------------
proc ParseTagValue uses esi ebx, pPos, pEnd
    mov esi, [pPos]
    mov dword [lTagValStart], 0
    mov dword [lTagValLen],   0
.Loop:
    cmp esi, [pEnd]
    jae .Done
    stdcall GetTagToken, esi
    tok_dbg
    test eax, eax
    jz .Done
    movzx ecx, byte [eax + Token.tType]
    mov edx, [eax + Token.cRead]
    test edx, edx
    jnz @F
    inc edx
@@:
    cmp ecx, TEXT_TAG
    je .GotText
    cmp ecx, TOKEN_FREE_LINE
    je .SkipLine
    invoke HeapFree, [hHeap], 0, eax    ; TagValue -> e
    jmp .Done
.GotText:
    cmp dword [lTagValStart], 0
    jne .AlreadySet
    mov ebx, [eax + Token.pStart]
    mov [lTagValStart], ebx
    mov [lTagValLen], edx
.AlreadySet:
    add esi, edx
    invoke HeapFree, [hHeap], 0, eax
    jmp .Loop
.SkipLine:
    add esi, edx
    invoke HeapFree, [hHeap], 0, eax
    jmp .Loop
.Done:
    mov [lParsePos], esi
    mov eax, 1
    ret
endp


; -----------------------------------------------------------
; proc FreeIR
; -----------------------------------------------------------
; @[proc]
; .parent:  Parser
; .name:    FreeIR
; .desc:    Walks IR linked list and frees all DocBlock nodes.
; .in:      pIR -> pointer to DocIR
; .out:     (none)
proc FreeIR uses eax ecx, pIR
    mov eax, [pIR]
    mov eax, [eax + DocIR.pFirst]
.Loop:
    test eax, eax
    jz .Done
    mov ecx, [eax + DocBlock.pNext]
    invoke HeapFree, [hHeap], 0, eax
    mov eax, ecx
    jmp .Loop
.Done: ret
endp


; -----------------------------------------------------------
; proc DumpIR  -- РїРµС‡Р°С‚Р°РµС‚ AST РІ РєРѕРЅСЃРѕР»СЊ
; -----------------------------------------------------------
; .in:  pIR -> pointer to DocIR
proc DumpIR uses eax ebx ecx edx esi, pIR
locals
    lFIdx   dd 0
    lFCnt   dd 0
endl
    invoke  WriteConsoleA, [hOutput], szAstHeader, szAstHeader.len, 0, 0

    mov     esi, [pIR]
    test    esi, esi
    jz      .Done
    mov     esi, [esi + DocIR.pFirst]

.BlockLoop:
    test    esi, esi
    jz      .Done

    ; === [BLOCK] type=<name> ===
    invoke  WriteConsoleA, [hOutput], szAstBlkHdr, szAstBlkHdr.len, 0, 0
    mov     eax, [esi + DocBlock.cType]
    test    eax, eax
    jz      .NoType
    invoke  WriteConsoleA, [hOutput], [esi + DocBlock.pType], \
                           [esi + DocBlock.cType], 0, 0
.NoType:
    invoke  WriteConsoleA, [hOutput], szAstNL, 2, 0, 0

    ; РїРѕР»СЏ
    mov     dword [lFIdx], 0
    mov     eax, [esi + DocBlock.fieldCount]
    mov     [lFCnt], eax

.FieldLoop:
    mov     eax, [lFIdx]
    cmp     eax, [lFCnt]
    jge     .FieldsDone

    imul    ecx, eax, sizeof.DocField
    lea     ebx, [esi + DocBlock.fields + ecx]

    ;   .name: value
    invoke  WriteConsoleA, [hOutput], szAstFldPfx, 3, 0, 0
    invoke  WriteConsoleA, [hOutput], [ebx + DocField.pName],  \
                           [ebx + DocField.cName],  0, 0
    invoke  WriteConsoleA, [hOutput], szAstFldSep, 2, 0, 0
    mov     eax, [ebx + DocField.cValue]
    test    eax, eax
    jz      .NoVal
    invoke  WriteConsoleA, [hOutput], [ebx + DocField.pValue], \
                           [ebx + DocField.cValue], 0, 0
    jmp     .AfterVal
.NoVal:
    invoke  WriteConsoleA, [hOutput], szAstNone, 6, 0, 0
.AfterVal:
    invoke  WriteConsoleA, [hOutput], szAstNL, 2, 0, 0

    inc     dword [lFIdx]
    jmp     .FieldLoop

.FieldsDone:
    invoke  WriteConsoleA, [hOutput], szAstDiv, szAstDiv.len, 0, 0
    mov     esi, [esi + DocBlock.pNext]
    jmp     .BlockLoop

.Done:
    mov     eax, 1
    ret
endp
