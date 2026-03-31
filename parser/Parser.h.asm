; IR structures for FASM AutoDocer Parser

MAX_FIELDS  equ 32

struct DocField
    pName   dd ?    ; pointer to tag name  (in file mapping)
    cName   dd ?    ; length of name
    pValue  dd ?    ; pointer to tag value (in file mapping)
    cValue  dd ?    ; length of value
ends

struct DocBlock
    pType       dd ?                            ; pointer to type string (in mapping)
    cType       dd ?                            ; length of type string
    fieldCount  dd ?                            ; number of fields stored
    fields      rb MAX_FIELDS * sizeof.DocField ; inline array of DocField
    pNext       dd ?                            ; linked-list -> next DocBlock
ends

struct DocIR
    pFirst      dd ?    ; pointer to first DocBlock
    blockCount  dd ?    ; total number of blocks
ends