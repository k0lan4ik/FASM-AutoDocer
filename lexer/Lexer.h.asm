CHAR_NULL       equ 0
CHAR_SPACE      equ 1
CHAR_SEMICOLON  equ 2   ; ;
CHAR_COLON      equ 3   ; :
CHAR_AT         equ 4   ; @
CHAR_DOT        equ 5   ; .
CHAR_OP_BRACK   equ 6   ; [
CHAR_CL_BRACK   equ 7   ; ]
CHAR_MINUS      equ 8   ; -
CHAR_MORE       equ 9   ; >
CHAR_NEWLINE    equ 10
CHAR_OTHER      equ 11

TOKEN_ERR           equ 0    
TOKEN_OPEN_TYPE     equ 1
TOKEN_CLOSE_TYPE    equ 2
TOKEN_OPEN_TAG      equ 3
TOKEN_IDEN          equ 4
TOKEN_CLOSE_TAG     equ 5
TOKEN_FREE_LINE     equ 6
TOKEN_SEM           equ 7
TEXT_TYPE           equ 8
TEXT_TAG            equ 9

;TOKEN_OPEN_TYPE = CHAR_SEMICOLON CHAR_SPACE* CHAR_AT CHAR_OP_BRACK
;TOKEN_CLOSE_TYPE = CHAR_CL_BRACK
;TOKEN_OPEN_TAG = CHAR_SEMICOLON CHAR_SPACE* CHAR_DOT
;TOKEN_IDEN = CHAR_OTHER+
;TOKEN_CLOSE_TAG = CHAR_COLON CHAR_SPACE*
;TOKEN_FREE_LINE = CHAR_SEMICOLON CHAR_SPACE*

;TEXT_TYPE = (ALL - CHAR_CL_BRACK - CHAR_NEWLINE)*
;TEXT_TAG = (ALL - CHAR_NEWLINE)*

struct  Token      
  pStart    dd ?           
  cRead     dd ?   
  tType     db ?        
ends            
