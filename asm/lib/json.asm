; =============================================================================
; lib/json.asm - JSON parsing functions
; =============================================================================
; All functions use 'json_' prefix to avoid naming collisions
;
; Exported functions:
;   json_extract_number   - Extract number from JSON
;   json_extract_string   - Extract string from JSON
;   json_find_ideas       - Find {"ideas":[...]} in response
;   json_unescape         - Unescape JSON string
; =============================================================================

section .text

; -----------------------------------------------------------------------------
; json_extract_number: Extract number from JSON after "key":
; Input:  rdi = source (after "key":), rsi = destination buffer
; Output: rax = 1 if success, 0 if failed
; -----------------------------------------------------------------------------
global json_extract_number
json_extract_number:
    push rcx

.skip_spaces:
    mov al, [rdi]
    cmp al, ' '
    jne .check_digit
    inc rdi
    jmp .skip_spaces

.check_digit:
    ; Verify it's a digit
    cmp al, '0'
    jb .fail
    cmp al, '9'
    ja .fail

    ; Copy digits
    xor rcx, rcx ; = mov rcx, 0 (optimise)
.copy_digits:
    mov al, [rdi]
    cmp al, '0'
    jb .digits_done
    cmp al, '9'
    ja .digits_done

    mov [rsi], al
    inc rsi
    inc rdi
    inc rcx
    cmp rcx, 15                 ; Max 15 digits
    jb .copy_digits

.digits_done:
    test rcx, rcx
    jz .fail

    mov byte [rsi], 0           ; Null-terminate
    mov rax, 1
    jmp .done

.fail:
    xor rax, rax ; = mov rax, 0 (optimise)

.done:
    pop rcx
    ret

; -----------------------------------------------------------------------------
; json_extract_string: Extract JSON string (between quotes)
; Input:  rdi = source (after "key":), rsi = destination
; Output: rax = 1 if success, 0 if failed
; -----------------------------------------------------------------------------
global json_extract_string
json_extract_string:
    push rcx

    ; Skip whitespace
.skip_spaces:
    mov al, [rdi]
    cmp al, ' '
    jne .check_quote
    inc rdi
    jmp .skip_spaces

.check_quote:
    cmp al, '"'
    jne .fail                   ; Must start with "
    inc rdi                     ; Skip opening "

    ; Copy until closing "
    xor rcx, rcx
.copy_loop:
    mov al, [rdi]
    test al, al
    jz .fail                    ; End of string without "

    cmp al, '"'
    je .string_done

    ; Handle escapes
    cmp al, '\'
    jne .copy_char
    inc rdi
    mov al, [rdi]
    test al, al
    jz .fail

.copy_char:
    mov [rsi], al
    inc rsi
    inc rdi
    inc rcx
    cmp rcx, 500                ; Max 500 chars
    jb .copy_loop

.string_done:
    test rcx, rcx
    jz .fail

    mov byte [rsi], 0           ; Null-terminate
    mov rax, 1
    jmp .done

.fail:
    xor rax, rax

.done:
    pop rcx
    ret

; -----------------------------------------------------------------------------
; json_find_ideas: Find {"ideas":[...]} JSON in Ollama response
; Input:  rdi = start of response (after "response":")
; Output: rax = start of JSON, rdx = length, or rax=0 if not found
; -----------------------------------------------------------------------------
global json_find_ideas
json_find_ideas:
    push rbx
    push rcx
    push rdx
    push r8

    mov r8, rdi                 ; Save start

.search_json:
    mov al, [rdi]
    test al, al
    jz .not_found

    ; Look for '{'
    cmp al, '{'
    je .found_brace

    ; Handle escapes in Ollama response
    cmp al, '\'
    jne .next_char
    inc rdi
    mov al, [rdi]
    test al, al
    jz .not_found

.next_char:
    inc rdi
    jmp .search_json

.found_brace:
    mov r8, rdi                 ; Mark potential start

    ; Verify it's {"ideas or {\"ideas or with whitespace
    mov rbx, rdi
    inc rbx

    ; Skip \n, \r, \t and spaces
.skip_whitespace:
    cmp byte [rbx], '\'
    jne .check_space
    mov al, [rbx+1]
    cmp al, 'n'
    je .skip_escape_seq
    cmp al, 'r'
    je .skip_escape_seq
    cmp al, 't'
    je .skip_escape_seq
    jmp .check_direct_quote

.skip_escape_seq:
    add rbx, 2
    jmp .skip_whitespace

.check_space:
    cmp byte [rbx], ' '
    jne .check_direct_quote
    inc rbx
    jmp .skip_whitespace

.check_direct_quote:
    cmp byte [rbx], '\'
    jne .check_quote
    inc rbx

.check_quote:
    cmp byte [rbx], '"'
    jne .next_char_continue
    inc rbx
    cmp byte [rbx], 'i'
    jne .next_char_continue
    inc rbx
    cmp byte [rbx], 'd'
    jne .next_char_continue
    inc rbx
    cmp byte [rbx], 'e'
    jne .next_char_continue
    inc rbx
    cmp byte [rbx], 'a'
    jne .next_char_continue
    inc rbx
    cmp byte [rbx], 's'
    jne .next_char_continue

    ; Found our JSON! Find the end
    mov rdi, r8
    xor rcx, rcx                ; Brace counter

.find_end:
    mov al, [rdi]
    test al, al
    jz .not_found

    cmp al, '{'
    jne .check_close
    inc rcx
    jmp .cont_find

.check_close:
    cmp al, '}'
    jne .check_escape
    dec rcx
    test rcx, rcx
    jz .found_end
    jmp .cont_find

.check_escape:
    cmp al, '\'
    jne .cont_find
    inc rdi                     ; Skip escaped char

.cont_find:
    inc rdi
    jmp .find_end

.found_end:
    inc rdi                     ; Include closing }
    mov rax, r8                 ; Start
    mov rdx, rdi
    sub rdx, r8                 ; Length
    jmp .done

.next_char_continue:
    inc rdi
    jmp .search_json

.not_found:
    xor rax, rax

.done:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; -----------------------------------------------------------------------------
; json_unescape: Convert escaped sequences to characters
; Input:  rdi = destination, rsi = source, r12 = source length
; Output: rax = length of result
; Transforms: \" -> ", \\ -> \, \n/\r/\t -> (skipped)
; -----------------------------------------------------------------------------
global json_unescape
json_unescape:
    push rcx
    push r8

    mov r8, rdi                 ; Save destination start
    mov rcx, r12                ; Bytes remaining

.loop:
    test rcx, rcx
    jz .done

    mov al, [rsi]

    ; Check for backslash (0x5C)
    cmp al, 0x5C
    jne .normal

    ; It's a backslash, look at next char
    dec rcx
    test rcx, rcx
    jz .done

    inc rsi
    mov al, [rsi]

    ; Convert escape sequences
    cmp al, 0x22                ; " (double quote)
    je .write
    cmp al, 0x5C                ; \ (backslash)
    je .write
    cmp al, 0x6E                ; n -> skip newline
    je .skip_whitespace
    cmp al, 0x72                ; r -> skip cr
    je .skip_whitespace
    cmp al, 0x74                ; t -> skip tab
    je .skip_whitespace

    ; Unknown sequence, keep character as-is
    jmp .write

.skip_whitespace:
    inc rsi
    dec rcx
    jmp .loop

.normal:
.write:
    mov [rdi], al
    inc rdi
    inc rsi
    dec rcx
    jmp .loop

.done:
    ; Calculate result length
    mov rax, rdi
    sub rax, r8

    pop r8
    pop rcx
    ret
