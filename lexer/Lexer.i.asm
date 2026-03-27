
TokenTableMain   \
     \  ;0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 0, 0, 5, 0, 0, 0, 4, 2, 2, 3, 2, \
        0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 2, \
        0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 6, 0, 0, 8, 7, 0, 0, 0, 0, 0, 0, \
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, \
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


TokenStateMain \
    db  TOKEN_ERR, TOKEN_ERR, TOKEN_IDEN, TOKEN_ERR, TOKEN_CLOSE_TYPE, TOKEN_CLOSE_TAG, \ 
    TOKEN_FREE_LINE, TOKEN_OPEN_TAG, TOKEN_ERR, TOKEN_OPEN_TYPE

TokenTableTag  \
     \  ;0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 2, 2, 2, 2, 2, 2, 2, 3, 2, 0, 2, \
        0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, \
        0, 2, 2, 2, 2, 2, 2, 2, 2, 4, 0, 2, \
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

TokenStateTag \
    db  TOKEN_ERR, TEXT_TAG, TEXT_TAG, TOKEN_ERR, TOKEN_SEM

TokenTableType \
    \   ;0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    db  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
        0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1




CharTable:
    times 256 db CHAR_OTHER

    store CHAR_NULL      at CharTable + 0
    store CHAR_SPACE     at CharTable + 9  ; Tab
    store CHAR_NEWLINE   at CharTable + 10 ; LF
    store CHAR_NEWLINE   at CharTable + 13 ; CR
    store CHAR_SPACE     at CharTable + 32 ; Space
    store CHAR_DOT       at CharTable + 46 ; .
    store CHAR_COLON     at CharTable + 58 ; :
    store CHAR_SEMICOLON at CharTable + 59 ; ;
    store CHAR_AT        at CharTable + 64 ; @
    store CHAR_OP_BRACK  at CharTable + 91 ; [
    store CHAR_CL_BRACK  at CharTable + 93 ; ]