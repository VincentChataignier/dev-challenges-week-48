; string_utils.inc - Fonctions de manipulation de chaînes
; ===========================================================================

; ---------------------------------------------------------------------------
; copy_mem: Copie rcx bytes de rsi vers rdi, avance rdi
; Entrée: rsi = source, rdi = destination, rcx = nombre de bytes
; Sortie: rdi avancé de rcx bytes
; ---------------------------------------------------------------------------
copy_mem:
    push rcx
    push rsi

    test rcx, rcx
    jz .copy_mem_done

.copy_mem_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_mem_loop

.copy_mem_done:
    pop rsi
    pop rcx
    ret

; ---------------------------------------------------------------------------
; copy_string: Copie une chaîne null-terminée de rsi vers rdi, avance rdi
; Entrée: rsi = source (null-terminée), rdi = destination
; Sortie: rdi avancé après le dernier caractère copié
; ---------------------------------------------------------------------------
copy_string:
    push rsi

.copy_str:
    mov al, [rsi]
    test al, al
    jz .copy_str_end
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .copy_str

.copy_str_end:
    pop rsi
    ret

; ---------------------------------------------------------------------------
; copy_escaped_string: Copie en échappant les " et \ pour JSON
; Entrée: rsi = source (null-terminée), rdi = destination
; Sortie: rdi avancé après le dernier caractère copié
; ---------------------------------------------------------------------------
copy_escaped_string:
    push rsi
    push rbx

.escape_loop:
    mov al, [rsi]
    test al, al
    jz .escape_done

    ; Échapper les caractères spéciaux
    cmp al, '"'
    je .escape_char
    cmp al, '\'
    je .escape_char
    cmp al, 10                  ; \n
    je .escape_newline
    cmp al, 13                  ; \r
    je .escape_cr

    ; Caractère normal
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .escape_loop

.escape_char:
    mov byte [rdi], '\'
    inc rdi
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .escape_loop

.escape_newline:
    mov byte [rdi], '\'
    inc rdi
    mov byte [rdi], 'n'
    inc rdi
    inc rsi
    jmp .escape_loop

.escape_cr:
    mov byte [rdi], '\'
    inc rdi
    mov byte [rdi], 'r'
    inc rdi
    inc rsi
    jmp .escape_loop

.escape_done:
    pop rbx
    pop rsi
    ret

; ---------------------------------------------------------------------------
; int_to_string: Convertit un entier en chaîne décimale
; Entrée: rax = nombre, rdi = buffer destination
; Sortie: rax = longueur de la chaîne
; ---------------------------------------------------------------------------
int_to_string:
    push rbx
    push rcx
    push rdx
    push rdi

    mov rbx, 10                 ; Diviseur
    xor rcx, rcx                ; Compteur de chiffres

    ; Cas spécial: 0
    test rax, rax
    jnz .convert_loop
    mov byte [rdi], '0'
    mov rax, 1
    jmp .int_to_str_done

.convert_loop:
    test rax, rax
    jz .reverse_string

    xor rdx, rdx
    div rbx                     ; rax = quotient, rdx = reste
    add dl, '0'
    push rdx                    ; Sauvegarder le chiffre
    inc rcx
    jmp .convert_loop

.reverse_string:
    mov rax, rcx                ; Sauvegarder longueur

.pop_loop:
    test rcx, rcx
    jz .int_to_str_done
    pop rdx
    mov [rdi], dl
    inc rdi
    dec rcx
    jmp .pop_loop

.int_to_str_done:
    mov byte [rdi], 0           ; Terminer

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; string_to_int: Convertit une chaîne de chiffres en entier
; Entrée: rsi = chaîne null-terminée
; Sortie: rax = valeur entière
; ---------------------------------------------------------------------------
string_to_int:
    push rbx
    push rcx

    xor rax, rax                ; Résultat = 0
    mov rbx, 10                 ; Multiplicateur

.str_to_int_loop:
    movzx rcx, byte [rsi]       ; Charger caractère
    test cl, cl                 ; Fin de chaîne ?
    jz .str_to_int_done

    ; Vérifier que c'est un chiffre
    cmp cl, '0'
    jb .str_to_int_done
    cmp cl, '9'
    ja .str_to_int_done

    ; rax = rax * 10 + (cl - '0')
    imul rax, rbx               ; rax *= 10
    sub cl, '0'                 ; Convertir ASCII -> valeur
    add rax, rcx                ; rax += digit

    inc rsi
    jmp .str_to_int_loop

.str_to_int_done:
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; find_substring: Cherche une sous-chaîne dans une chaîne
; Entrée: rdi = chaîne source, rsi = sous-chaîne, rdx = longueur sous-chaîne
; Sortie: rax = pointeur après la sous-chaîne trouvée, ou 0 si non trouvée
; ---------------------------------------------------------------------------
find_substring:
    push rbx
    push rcx
    push r8
    push r9

    mov r8, rdi                 ; r8 = source
    mov r9, rsi                 ; r9 = pattern
    mov rcx, rdx                ; rcx = pattern length

.find_loop:
    ; Vérifier si on est à la fin de la source
    mov al, [r8]
    test al, al
    jz .find_not_found

    ; Comparer pattern
    push rcx
    push r8
    push r9

.compare_loop:
    test rcx, rcx
    jz .find_found_pop

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
    jmp .find_loop

.find_found_pop:
    pop r9
    pop r8
    pop rcx

    ; Retourner pointeur après le pattern
    lea rax, [r8 + rcx]
    jmp .find_done

.find_not_found:
    xor rax, rax

.find_done:
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret