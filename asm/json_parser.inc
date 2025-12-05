; json_parser.inc - Fonctions de parsing JSON
; ===========================================================================

; ---------------------------------------------------------------------------
; extract_number: Extrait un nombre d'une chaîne JSON
; Entrée: rdi = source (après "key":), rsi = destination buffer
; Sortie: rax = 1 si succès, 0 sinon
; ---------------------------------------------------------------------------
extract_number:
    push rbx
    push rcx

    ; Sauter les espaces
.skip_spaces:
    mov al, [rdi]
    cmp al, ' '
    jne .check_digit
    inc rdi
    jmp .skip_spaces

.check_digit:
    ; Vérifier que c'est un chiffre
    cmp al, '0'
    jb .extract_num_fail
    cmp al, '9'
    ja .extract_num_fail

    ; Copier les chiffres
    xor rcx, rcx                ; Compteur
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
    cmp rcx, 15                 ; Max 15 chiffres
    jb .copy_digits

.digits_done:
    test rcx, rcx
    jz .extract_num_fail

    mov byte [rsi], 0           ; Terminer
    mov rax, 1
    jmp .extract_num_done

.extract_num_fail:
    xor rax, rax

.extract_num_done:
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; extract_string: Extrait une chaîne JSON (entre quotes)
; Entrée: rdi = source (après "key":), rsi = destination
; Sortie: rax = 1 si succès, 0 sinon
; ---------------------------------------------------------------------------
extract_string:
    push rbx
    push rcx

    ; Sauter les espaces
.skip_str_spaces:
    mov al, [rdi]
    cmp al, ' '
    jne .check_quote
    inc rdi
    jmp .skip_str_spaces

.check_quote:
    cmp al, '"'
    jne .extract_str_fail       ; Doit commencer par "
    inc rdi                     ; Sauter le "

    ; Copier jusqu'au " fermant
    xor rcx, rcx
.copy_str_loop:
    mov al, [rdi]
    test al, al
    jz .extract_str_fail        ; Fin de chaîne sans "

    cmp al, '"'
    je .str_done

    ; Gérer les échappements
    cmp al, '\'
    jne .copy_char
    inc rdi
    mov al, [rdi]
    test al, al
    jz .extract_str_fail

.copy_char:
    mov [rsi], al
    inc rsi
    inc rdi
    inc rcx
    cmp rcx, 500                ; Max 500 chars
    jb .copy_str_loop

.str_done:
    test rcx, rcx
    jz .extract_str_fail

    mov byte [rsi], 0
    mov rax, 1
    jmp .extract_str_done

.extract_str_fail:
    xor rax, rax

.extract_str_done:
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; find_json_in_response: Trouve le JSON {"ideas":[...]} dans la réponse Ollama
; Entrée: rdi = début de la réponse (après "response":")
; Sortie: rax = début du JSON, rdx = longueur, ou rax=0 si non trouvé
; ---------------------------------------------------------------------------
find_json_in_response:
    push rbx
    push rcx
    push r8

    mov r8, rdi                 ; Sauvegarder début

    ; Chercher {"ideas" dans la réponse (peut être échappé ou non)
.search_json:
    mov al, [rdi]
    test al, al
    jz .json_not_found

    ; Chercher '{'
    cmp al, '{'
    je .found_brace

    ; Gérer les échappements dans la réponse Ollama
    cmp al, '\'
    jne .next_char
    inc rdi
    mov al, [rdi]
    test al, al
    jz .json_not_found

.next_char:
    inc rdi
    jmp .search_json

.found_brace:
    mov r8, rdi                 ; Marquer début potentiel

    ; Vérifier si c'est {"ideas ou {\"ideas ou {\n\"ideas (avec newlines)
    mov rbx, rdi
    inc rbx

    ; Sauter les séquences \n, \r, \t et espaces
.skip_whitespace:
    cmp byte [rbx], '\'
    jne .check_space
    ; C'est un backslash, vérifier si c'est \n, \r ou \t
    mov al, [rbx+1]
    cmp al, 'n'
    je .skip_escape_seq
    cmp al, 'r'
    je .skip_escape_seq
    cmp al, 't'
    je .skip_escape_seq
    ; C'est peut-être \" ou autre chose
    jmp .check_direct_quote

.skip_escape_seq:
    add rbx, 2                  ; Sauter \n, \r ou \t
    jmp .skip_whitespace

.check_space:
    cmp byte [rbx], ' '
    jne .check_direct_quote
    inc rbx
    jmp .skip_whitespace

.check_direct_quote:
    ; Vérifier le \" (backslash + quote) ou juste "
    cmp byte [rbx], '\'
    jne .check_quote_direct
    inc rbx                     ; Sauter le backslash

.check_quote_direct:
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

    ; C'est notre JSON! Trouver la fin
    mov rdi, r8
    xor rcx, rcx                ; Compteur de braces

.find_end:
    mov al, [rdi]
    test al, al
    jz .json_not_found

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
    inc rdi                     ; Sauter le caractère échappé

.cont_find:
    inc rdi
    jmp .find_end

.found_end:
    inc rdi                     ; Inclure le }
    mov rax, r8                 ; Début
    mov rdx, rdi
    sub rdx, r8                 ; Longueur
    jmp .json_done

.next_char_continue:
    inc rdi
    jmp .search_json

.json_not_found:
    xor rax, rax

.json_done:
    pop r8
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; unescape_json: Convertit les séquences échappées en caractères
; Entrée: rdi = destination, rsi = source, r12 = longueur source
; Sortie: rax = longueur du résultat
; Transforme: \" -> ", \\ -> \, \n/\r/\t -> (ignorés)
; ---------------------------------------------------------------------------
unescape_json:
    push rbx
    push rcx
    push rdx
    push r8

    mov r8, rdi                 ; Sauvegarder début destination
    mov rcx, r12                ; Compteur de bytes restants

.unescape_loop:
    test rcx, rcx
    jz .unescape_done

    mov al, [rsi]

    ; Vérifier si c'est un backslash (0x5C)
    cmp al, 0x5C
    jne .unescape_normal

    ; C'est un backslash, regarder le caractère suivant
    dec rcx
    test rcx, rcx
    jz .unescape_done           ; Pas de caractère après

    inc rsi
    mov al, [rsi]

    ; Convertir les séquences d'échappement
    cmp al, 0x22                ; " (double quote)
    je .unescape_write
    cmp al, 0x5C                ; \ (backslash)
    je .unescape_write
    cmp al, 0x6E                ; n -> skip newline
    je .unescape_whitespace
    cmp al, 0x72                ; r -> skip cr
    je .unescape_whitespace
    cmp al, 0x74                ; t -> skip tab
    je .unescape_whitespace

    ; Séquence inconnue, garder le caractère tel quel
    jmp .unescape_write

.unescape_whitespace:
    ; Sauter les whitespace escapes (ne pas les inclure dans output)
    inc rsi
    dec rcx
    jmp .unescape_loop

.unescape_normal:
.unescape_write:
    mov [rdi], al
    inc rdi
    inc rsi
    dec rcx
    jmp .unescape_loop

.unescape_done:
    ; Calculer longueur du résultat
    mov rax, rdi
    sub rax, r8

    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret