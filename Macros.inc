macro ustr0 name, content& {
    common
        name du content
        name#.length = ($ - name) / 2
        du 0
}

; ---- macro: dump token without clobbering eax --------------
; После stdcall GetToken/GetTypeToken/GetTagToken:
;   push eax
;   stdcall DumpToken, eax   ; DumpToken сохраняет/восстанавливает все регистры
;   pop  eax                  ; возвращаем указатель на токен
; ------------------------------------------------------------
macro tok_dbg {
    push eax
    stdcall DumpToken, eax
    pop  eax
}