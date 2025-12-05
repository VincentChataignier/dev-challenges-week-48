; gift_core.asm - Générateur d'idées cadeaux en ASM pur x86_64
; Lit un JSON depuis stdin, appelle Ollama via socket TCP, retourne les idées
;
; Compilation:
;   nasm -felf64 gift_core.asm -o gift_core.o
;   ld -o gift_core gift_core.o

; ===========================================================================
; INCLUDES
; ===========================================================================
%include "constants.inc"
%include "data.inc"

; ===========================================================================
; SECTION TEXT - Code exécutable
; ===========================================================================
section .text
    global _start

; ===========================================================================
; POINT D'ENTRÉE
; ===========================================================================
_start:
    ; -----------------------------------------------------------------------
    ; ÉTAPE 1: Lire stdin dans input_buffer
    ; -----------------------------------------------------------------------
    mov rax, SYS_READ
    mov rdi, STDIN
    lea rsi, [input_buffer]
    mov rdx, INPUT_SIZE - 1
    syscall

    ; Vérifier erreur de lecture
    test rax, rax               ; Modifie les flags ZF et SF, je vais ensuite les lire avec js et jz
    js .error_json              ; JumpifSign -> Si négatif, erreur
    jz .error_json              ; JumpifZero -> Si 0, entrée vide

    ; Sauvegarder la longueur - Écris la valeur qui est dans rax dans la variable input_len
    mov [input_len], rax

    ; Terminer la chaîne par null
    lea rdi, [input_buffer]
    add rdi, rax
    mov byte [rdi], 0

    ; -----------------------------------------------------------------------
    ; ÉTAPE 2: Parser le JSON - extraire "age" et "interests"
    ; -----------------------------------------------------------------------

    ; Chercher "age":
    lea rdi, [input_buffer]
    lea rsi, [key_age]
    mov rdx, key_age_len
    call find_substring
    test rax, rax
    jz .error_json              ; "age" non trouvé

    ; rax pointe après "age":, extraire le nombre
    lea rdi, [rax]
    lea rsi, [age_buffer]
    call extract_number
    test rax, rax
    jz .error_json              ; Pas de nombre valide

    ; Valider que age > 0
    lea rsi, [age_buffer]
    call string_to_int          ; Convertir en entier dans rax
    test rax, rax
    jz .error_json              ; age == 0 est invalide

    ; Chercher "interests":
    lea rdi, [input_buffer]
    lea rsi, [key_interests]
    mov rdx, key_interests_len
    call find_substring
    test rax, rax
    jz .error_json              ; "interests" non trouvé

    ; rax pointe après "interests":, extraire la chaîne
    lea rdi, [rax]
    lea rsi, [interests_buffer]
    call extract_string
    test rax, rax
    jz .error_json              ; Pas de chaîne valide

    ; -----------------------------------------------------------------------
    ; ÉTAPE 3: Construire le prompt pour Ollama
    ; -----------------------------------------------------------------------
    lea rdi, [prompt_buffer]

    ; Copier prefix
    lea rsi, [prompt_prefix]
    mov rcx, prompt_prefix_len
    call copy_mem

    ; Copier age
    lea rsi, [age_buffer]
    call copy_string

    ; Copier middle
    lea rsi, [prompt_middle]
    mov rcx, prompt_middle_len
    call copy_mem

    ; Copier interests
    lea rsi, [interests_buffer]
    call copy_string

    ; Copier suffix
    lea rsi, [prompt_suffix]
    mov rcx, prompt_suffix_len
    call copy_mem

    ; Terminer par null
    mov byte [rdi], 0

    ; Calculer longueur du prompt
    lea rax, [prompt_buffer]
    sub rdi, rax
    push rdi                    ; Sauvegarder longueur du prompt

    ; -----------------------------------------------------------------------
    ; ÉTAPE 4: Créer le socket TCP
    ; -----------------------------------------------------------------------
    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx                ; protocol = 0
    syscall

    test rax, rax
    js .error_socket

    mov [socket_fd], rax

    ; -----------------------------------------------------------------------
    ; ÉTAPE 5: Se connecter à Ollama
    ; -----------------------------------------------------------------------
    mov rax, SYS_CONNECT
    mov rdi, [socket_fd]
    lea rsi, [sockaddr]
    mov rdx, sockaddr_len
    syscall

    test rax, rax
    jnz .error_connect

    ; -----------------------------------------------------------------------
    ; ÉTAPE 6: Construire la requête HTTP
    ; -----------------------------------------------------------------------
    pop r12                     ; Récupérer longueur du prompt (non utilisé ici)

    ; D'abord construire le body JSON pour calculer sa vraie taille
    ; (après échappement)
    lea rdi, [http_request]     ; Utiliser temporairement http_request comme buffer
    add rdi, 512                ; Offset pour laisser place aux headers

    mov r14, rdi                ; Sauvegarder début du body

    ; Copier body start
    lea rsi, [http_body_start]
    mov rcx, http_body_start_len
    call copy_mem

    ; Copier prompt (avec échappement des quotes)
    lea rsi, [prompt_buffer]
    call copy_escaped_string

    ; Copier body end
    lea rsi, [http_body_end]
    mov rcx, http_body_end_len
    call copy_mem

    ; Calculer taille du body
    mov rax, rdi
    sub rax, r14                ; rax = taille réelle du body
    push rax                    ; Sauvegarder taille body
    push rdi                    ; Sauvegarder fin du body

    ; Convertir taille en string
    lea rdi, [content_len_str]
    call int_to_string
    mov r13, rax                ; r13 = longueur du string Content-Length

    ; Maintenant construire la vraie requête HTTP
    lea rdi, [http_request]

    ; Copier headers
    lea rsi, [http_post]
    mov rcx, http_post_len
    call copy_mem

    ; Copier Content-Length value
    lea rsi, [content_len_str]
    mov rcx, r13
    call copy_mem

    ; Ajouter \r\n\r\n
    lea rsi, [crlf2]
    mov rcx, 4
    call copy_mem

    ; Copier le body qu'on a construit plus haut
    pop r15                     ; Fin du body
    pop rcx                     ; Taille du body
    mov rsi, r14                ; Début du body (à l'offset 512)
    call copy_mem

    ; Calculer taille totale de la requête
    lea rax, [http_request]
    sub rdi, rax
    mov r14, rdi                ; r14 = taille requête

    ; -----------------------------------------------------------------------
    ; ÉTAPE 7: Envoyer la requête HTTP
    ; -----------------------------------------------------------------------
    mov rax, SYS_WRITE
    mov rdi, [socket_fd]
    lea rsi, [http_request]
    mov rdx, r14
    syscall

    test rax, rax
    js .error_socket

    ; -----------------------------------------------------------------------
    ; ÉTAPE 8: Lire la réponse HTTP (en boucle)
    ; -----------------------------------------------------------------------
    lea r15, [response_buffer]  ; Pointeur courant dans le buffer
    xor r14, r14                ; Total bytes lus

.read_loop:
    mov rax, SYS_READ
    mov rdi, [socket_fd]
    mov rsi, r15
    mov rdx, RESPONSE_SIZE
    sub rdx, r14                ; Espace restant
    jz .read_done               ; Buffer plein
    syscall

    test rax, rax
    jle .read_done              ; EOF ou erreur

    add r14, rax                ; Ajouter au total
    add r15, rax                ; Avancer le pointeur
    jmp .read_loop

.read_done:
    ; Fermer le socket
    mov rax, SYS_CLOSE
    mov rdi, [socket_fd]
    syscall

    ; Terminer la réponse par null
    mov byte [r15], 0

    ; Vérifier qu'on a reçu quelque chose
    test r14, r14
    jz .error_response

    ; -----------------------------------------------------------------------
    ; ÉTAPE 9: Parser la réponse - chercher "response":"..."
    ; -----------------------------------------------------------------------
    lea rdi, [response_buffer]
    lea rsi, [key_response]
    mov rdx, key_response_len
    call find_substring
    test rax, rax
    jz .error_response

    ; rax pointe après "response":"
    mov rdi, rax

    ; Chercher le JSON dans la réponse (entre les accolades)
    call find_json_in_response
    test rax, rax
    jz .error_response

    ; rax = début du JSON, rdx = longueur
    mov rsi, rax
    mov r12, rdx

    ; -----------------------------------------------------------------------
    ; ÉTAPE 10: Unescape et écrire le résultat sur stdout
    ; -----------------------------------------------------------------------

    ; Unescape le JSON (convertir \" en ", \\ en \, etc.)
    lea rdi, [output_buffer]
    ; rsi = source (JSON échappé)
    ; r12 = longueur source
    call unescape_json
    ; rax = longueur du résultat unescaped

    ; Écrire le JSON propre
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [output_buffer]
    syscall

    ; Ajouter newline
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [crlf]
    mov rdx, 1
    syscall

    ; Succès!
    xor rdi, rdi
    jmp .exit

; ---------------------------------------------------------------------------
; GESTIONNAIRES D'ERREURS
; ---------------------------------------------------------------------------
.error_json:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    lea rsi, [err_json]
    mov rdx, err_json_len
    syscall
    mov rdi, EXIT_INPUT_ERR
    jmp .exit

.error_socket:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    lea rsi, [err_socket]
    mov rdx, err_socket_len
    syscall
    mov rdi, EXIT_RUNTIME_ERR
    jmp .exit

.error_connect:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    lea rsi, [err_connect]
    mov rdx, err_connect_len
    syscall
    mov rdi, EXIT_RUNTIME_ERR
    jmp .exit

.error_response:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    lea rsi, [err_response]
    mov rdx, err_response_len
    syscall
    mov rdi, EXIT_RUNTIME_ERR
    jmp .exit

.exit:
    mov rax, SYS_EXIT
    syscall

; ===========================================================================
; INCLUDES DES FONCTIONS UTILITAIRES
; ===========================================================================
%include "string_utils.inc"
%include "json_parser.inc"
