; ============================================================
;  Parser -- LL(1) recursive-descent
;  Grammar (from Parser.i.asm):
;    Document = Block Document | Any Document | e
;    Block    = TOKEN_OPEN_TYPE TypeID TOKEN_CLOSE_TYPE Body
;    Body     = Field Body | e
;    Field    = TOKEN_OPEN_TAG TagName TOKEN_CLOSE_TAG TagValue
; ============================================================

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
    lEnd    dd 0    ; one-past-end pointer
    lTok    dd 0    ; current token pointer
    lBlock  dd 0    ; current DocBlock pointer
endl
    mov     esi, [pBuf]
    mov     eax, [pBuf]
    add     eax, [nBytes]
    mov     [lEnd], eax

    ; zero IR
    mov     edi, [pIR]
    mov     dword [edi + DocIR.pFirst],     0
    mov     dword [edi + DocIR.blockCount], 0

.ScanLoop:
    cmp     esi, [lEnd]
    jae     .Done

    stdcall GetToken, esi
    test    eax, eax
    jz      .Done
    mov     [lTok], eax

    ; advance cursor (min 1 to avoid infinite loop)
    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    add     esi, edx

    movzx   ecx, byte [eax + Token.tType]
    cmp     ecx, TOKEN_OPEN_TYPE
    jne     .SkipTok

    ; --- got @[ --- get type text ---
    stdcall GetTypeToken, esi
    test    eax, eax
    jz      .FreeLTok

    movzx   ecx, byte [eax + Token.tType]
    cmp     ecx, TEXT_TYPE
    jne     .FreeTypeTok

    ; save type info before freeing
    push    dword [eax + Token.pStart]
    push    dword [eax + Token.cRead]

    ; advance past type text
    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    add     esi, edx
    invoke  HeapFree, [hHeap], 0, eax

    ; --- skip CLOSE_TYPE ']' ---
    stdcall GetToken, esi
    test    eax, eax
    jz      .PopAndFreeLTok

    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    movzx   ecx, byte [eax + Token.tType]
    invoke  HeapFree, [hHeap], 0, eax
    cmp     ecx, TOKEN_CLOSE_TYPE
    jne     .PopAndFreeLTok
    add     esi, edx

    ; --- allocate DocBlock ---
    invoke  HeapAlloc, [hHeap], 8, sizeof.DocBlock
    test    eax, eax
    jz      .PopAndFreeLTok
    mov     [lBlock], eax

    ; zero block
    push    edi ecx
    mov     edi, eax
    mov     ecx, sizeof.DocBlock / 4
    xor     eax, eax
    rep     stosd
    pop     ecx edi

    ; fill type info (popped from stack: cRead then pStart)
    mov     ebx, [lBlock]
    pop     dword [ebx + DocBlock.cType]
    pop     dword [ebx + DocBlock.pType]

    ; --- parse fields ---
.FieldLoop:
    cmp     esi, [lEnd]
    jae     .Attach

    stdcall GetToken, esi
    test    eax, eax
    jz      .Attach

    movzx   ecx, byte [eax + Token.tType]
    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    cmp     ecx, TOKEN_OPEN_TAG
    je      .DoField
    ; FREE_LINE / SEMICOLON -> skip
    cmp     ecx, TOKEN_FREE_LINE
    je      .SkipLine
    cmp     ecx, TOKEN_SEM
    je      .SkipLine
    ; anything else -> block ended
    invoke  HeapFree, [hHeap], 0, eax
    jmp     .Attach

.SkipLine:
    invoke  HeapFree, [hHeap], 0, eax
    add     esi, edx
    jmp     .FieldLoop

.DoField:
    invoke  HeapFree, [hHeap], 0, eax
    add     esi, edx     ; skip OPEN_TAG

    ; get tag name (IDEN)
    stdcall GetToken, esi
    test    eax, eax
    jz      .Attach

    movzx   ecx, byte [eax + Token.tType]
    cmp     ecx, TOKEN_IDEN
    jne     .FreeIdenAndAttach

    push    eax          ; save IDEN token

    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    add     esi, edx

    ; get CLOSE_TAG ':'
    stdcall GetToken, esi
    test    eax, eax
    jz      .PopIdenAttach

    movzx   ecx, byte [eax + Token.tType]
    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    invoke  HeapFree, [hHeap], 0, eax
    cmp     ecx, TOKEN_CLOSE_TAG
    jne     .PopIdenAttach
    add     esi, edx

    ; get tag value (TEXT_TAG)
    stdcall GetTagToken, esi
    test    eax, eax
    jz      .PopIdenAttach

    pop     ecx          ; ecx = IDEN token, eax = value token

    ; advance cursor
    mov     edx, [eax + Token.cRead]
    test    edx, edx
    jnz     @F
    inc     edx
@@:
    add     esi, edx

    ; store field if slot available
    mov     ebx, [lBlock]
    mov     edi, [ebx + DocBlock.fieldCount]
    cmp     edi, MAX_FIELDS
    jge     .FreeField

    imul    edi, sizeof.DocField
    lea     edi, [ebx + DocBlock.fields + edi]

    mov     edx, [ecx + Token.pStart]
    mov     [edi + DocField.pName],  edx
    mov     edx, [ecx + Token.cRead]
    mov     [edi + DocField.cName],  edx
    mov     edx, [eax + Token.pStart]
    mov     [edi + DocField.pValue], edx
    mov     edx, [eax + Token.cRead]
    mov     [edi + DocField.cValue], edx

    inc     dword [ebx + DocBlock.fieldCount]

.FreeField:
    invoke  HeapFree, [hHeap], 0, ecx
    invoke  HeapFree, [hHeap], 0, eax
    jmp     .FieldLoop

.PopIdenAttach:
    pop     ecx
    invoke  HeapFree, [hHeap], 0, ecx
    jmp     .Attach

.FreeIdenAndAttach:
    invoke  HeapFree, [hHeap], 0, eax
    jmp     .Attach

.Attach:
    ; append block to IR linked list
    mov     eax, [lBlock]
    mov     edi, [pIR]

    mov     ebx, [edi + DocIR.pFirst]
    test    ebx, ebx
    jnz     .WalkToTail
    mov     [edi + DocIR.pFirst], eax
    jmp     .Attached
.WalkToTail:
    mov     ecx, [ebx + DocBlock.pNext]
    test    ecx, ecx
    jz      .FoundTail
    mov     ebx, ecx
    jmp     .WalkToTail
.FoundTail:
    mov     [ebx + DocBlock.pNext], eax
.Attached:
    inc     dword [edi + DocIR.blockCount]

.FreeLTok:
    invoke  HeapFree, [hHeap], 0, [lTok]
    jmp     .ScanLoop

.PopAndFreeLTok:
    pop     eax  ; cRead
    pop     eax  ; pStart
    invoke  HeapFree, [hHeap], 0, [lTok]
    jmp     .ScanLoop

.FreeTypeTok:
    invoke  HeapFree, [hHeap], 0, eax
.SkipTok:
    invoke  HeapFree, [hHeap], 0, [lTok]
    jmp     .ScanLoop

.Done:
    mov     eax, 1
    ret
endp


; @[proc]
; .parent:  Parser
; .name:    FreeIR
; .desc:    Walks IR linked list and frees all DocBlock nodes.
; .in:      pIR -> pointer to DocIR
; .out:     (none)
proc FreeIR uses eax ecx, pIR
    mov     eax, [pIR]
    mov     eax, [eax + DocIR.pFirst]
.Loop:
    test    eax, eax
    jz      .Done
    mov     ecx, [eax + DocBlock.pNext]
    invoke  HeapFree, [hHeap], 0, eax
    mov     eax, ecx
    jmp     .Loop
.Done:
    ret
endp