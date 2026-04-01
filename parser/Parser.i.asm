;TOKEN_OPEN_TYPE = CHAR_NEWLINE CHAR_SEMICOLON CHAR_SPACE* CHAR_AT CHAR_OP_BRACK
;TOKEN_CLOSE_TYPE = CHAR_CL_BRACK
;TOKEN_OPEN_TAG = CHAR_NEWLINE CHAR_SEMICOLON CHAR_SPACE* CHAR_DOT
;TOKEN_IDEN = CHAR_OTHER+
;TOKEN_CLOSE_TAG = CHAR_COLON CHAR_SPACE*
;TOKEN_FREE_LINE = CHAR_NEWLINE CHAR_SEMICOLON CHAR_SPACE*

;TEXT_TYPE = (ALL - CHAR_CL_BRACK - CHAR_NEWLINE)*
;TEXT_TAG = (ALL - CHAR_NEWLINE)*

; Document = Block Document | Any Document | e
; Block = TOKEN_OPEN_TYPE TypeID TOKEN_CLOSE_TYPE Body
; TypeID = TEXT_TYPE
; Body = Field Body | e
; Field = TOKEN_OPEN_TAG TagName TOKEN_CLOSE_TAG TagValue 
; TagName = TOKEN_IDEN
; TagValue = TEXT_TAG TagValue | TOKEN_FREE_LINE TagValue | e

szErrNoTextType     db  '[PARSER ERROR] Expected TEXT_TYPE after TOKEN_OPEN_TYPE', 13, 10
szErrNoTextType.len = $ - szErrNoTextType

szErrNoCloseType    db  '[PARSER ERROR] Expected TOKEN_CLOSE_TYPE', 13, 10
szErrNoCloseType.len = $ - szErrNoCloseType

szErrNoIden         db  '[PARSER ERROR] Expected TOKEN_IDEN (tag name)', 13, 10
szErrNoIden.len = $ - szErrNoIden

szErrNoCloseTag     db  '[PARSER ERROR] Expected TOKEN_CLOSE_TAG', 13, 10
szErrNoCloseTag.len = $ - szErrNoCloseTag

szErrAllocFail      db  '[PARSER ERROR] HeapAlloc failed (DocBlock)', 13, 10
szErrAllocFail.len = $ - szErrAllocFail

lParsePos    dd 0   ; обновляется каждым ParseXxx
lTagValStart dd 0   ; результат ParseTagValue: pStart
lTagValLen   dd 0   ; результат ParseTagValue: cRead