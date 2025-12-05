; =============================================================================
; lib/string.asm - String manipulation functions
; =============================================================================
; All functions use 'str_' prefix to avoid naming collisions
;
; Exported functions:
;   str_copy_mem          - Copy N bytes from src to dst
;   str_copy              - Copy null-terminated string
;   str_copy_escaped      - Copy with JSON escaping
;   str_to_int            - Convert string to integer
;   str_from_int          - Convert integer to string
;   str_find              - Find substring in string
; =============================================================================

section .text

; -----------------------------------------------------------------------------
; str_copy_mem: Copy rcx bytes from rsi to rdi, advance rdi
; Input:  rsi = source, rdi = destination, rcx = byte count
; Output: rdi advanced by rcx bytes
; Clobbers: rax
; -----------------------------------------------------------------------------
global str_copy_mem
str_copy_mem:
    push rcx
    push rsi

    test rcx, rcx
    jz .done

.loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .loop

.done:
    pop rsi
    pop rcx
    ret

; -----------------------------------------------------------------------------
; str_copy: Copy null-terminated string from rsi to rdi, advance rdi
; Input:  rsi = source (null-terminated), rdi = destination
; Output: rdi advanced past last copied character
; Clobbers: rax
; -----------------------------------------------------------------------------
global str_copy
str_copy:
    push rsi

.loop:
    mov al, [rsi]
    test al, al
    jz .done
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .loop

.done:
    pop rsi
    ret

; -----------------------------------------------------------------------------
; str_copy_escaped: Copy with JSON escaping (" and \ become \" and \\)
; Input:  rsi = source (null-terminated), rdi = destination
; Output: rdi advanced past last copied character
; Clobbers: rax
; -----------------------------------------------------------------------------
global str_copy_escaped
str_copy_escaped:
    push rsi
    push rbx

.loop:
    mov al, [rsi]
    test al, al
    jz .done

    ; Check for special characters
    cmp al, '"'
    je .escape_char
    cmp al, '\'
    je .escape_char
    cmp al, 10                  ; \n
    je .escape_newline
    cmp al, 13                  ; \r
    je .escape_cr

    ; Normal character
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .loop

.escape_char:
    mov byte [rdi], '\'
    inc rdi
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .loop

.escape_newline:
    mov byte [rdi], '\'
    inc rdi
    mov byte [rdi], 'n'
    inc rdi
    inc rsi
    jmp .loop

.escape_cr:
    mov byte [rdi], '\'
    inc rdi
    mov byte [rdi], 'r'
    inc rdi
    inc rsi
    jmp .loop

.done:
    pop rbx
    pop rsi
    ret

; -----------------------------------------------------------------------------
; str_to_int: Convert decimal string to integer
; Input:  rsi = null-terminated string
; Output: rax = integer value
; Clobbers: rbx, rcx
; -----------------------------------------------------------------------------
global str_to_int
str_to_int:
    push rbx
    push rcx

    xor rax, rax                ; Result = 0
    mov rbx, 10                 ; Multiplier

.loop:
    movzx rcx, byte [rsi]
    test cl, cl
    jz .done

    ; Check if digit
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done

    ; rax = rax * 10 + (cl - '0')
    imul rax, rbx
    sub cl, '0'
    add rax, rcx

    inc rsi
    jmp .loop

.done:
    pop rcx
    pop rbx
    ret

; -----------------------------------------------------------------------------
; str_from_int: Convert integer to decimal string
; Input:  rax = number, rdi = destination buffer
; Output: rax = length of resulting string
; Clobbers: rbx, rcx, rdx
; -----------------------------------------------------------------------------
global str_from_int
str_from_int:
    push rbx
    push rcx
    push rdx
    push rdi

    mov rbx, 10                 ; Divisor
    xor rcx, rcx                ; Digit counter

    ; Special case: 0
    test rax, rax
    jnz .convert_loop
    mov byte [rdi], '0'
    mov rax, 1
    jmp .done

.convert_loop:
    test rax, rax
    jz .reverse

    xor rdx, rdx
    div rbx                     ; rax = quotient, rdx = remainder
    add dl, '0'
    push rdx                    ; Save digit
    inc rcx
    jmp .convert_loop

.reverse:
    mov rax, rcx                ; Save length

.pop_loop:
    test rcx, rcx
    jz .done
    pop rdx
    mov [rdi], dl
    inc rdi
    dec rcx
    jmp .pop_loop

.done:
    mov byte [rdi], 0           ; Null-terminate

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; -----------------------------------------------------------------------------
; str_find: Find substring in string
; Input:  rdi = haystack, rsi = needle, rdx = needle length
; Output: rax = pointer after found substring, or 0 if not found
; Clobbers: rbx, rcx, r8, r9
; -----------------------------------------------------------------------------
global str_find
str_find:
    push rbx
    push rcx
    push r8
    push r9

    mov r8, rdi                 ; r8 = source
    mov r9, rsi                 ; r9 = pattern
    mov rcx, rdx                ; rcx = pattern length

.search_loop:
    mov al, [r8]
    test al, al
    jz .not_found

    ; Compare pattern
    push rcx
    push r8
    push r9

.compare_loop:
    test rcx, rcx
    jz .found_pop

    mov al, [r8]
    mov bl, [r9]
    cmp al, bl
    jne .compare_fail

    inc r8
    inc r9
    dec rcx
    jmp .compare_loop

.compare_fail:
    pop r9
    pop r8
    pop rcx
    inc r8
    jmp .search_loop

.found_pop:
    pop r9
    pop r8
    pop rcx

    ; Return pointer after pattern
    lea rax, [r8 + rcx]
    jmp .done

.not_found:
    xor rax, rax

.done:
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret
