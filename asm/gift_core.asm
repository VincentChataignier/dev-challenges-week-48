; gift_core.asm
; Stub ASM - Linux x86_64
; Retourne un JSON avec 5 idees
;
; Je vais ajouter des commentaires pour comprendre l'ASM pendant que je code, et l'expliquer !
;
; Compilation :
;   nasm -felf64 gift_core.asm -o gift_core.o
;   ld -o gift_core gift_core.o

; ---------------------------------------------------------------------------
; PREAMBULE — QU'EST-CE QUE ELF ET QU'EST-CE QUE NASM ?
;
; ELF (Executable and Linkable Format)
; -----------------------------------
; ELF est le format standard des exécutables, bibliothèques et objets sous Linux.
; C’est lui qui définit les "sections" (.text, .data, .bss, etc.), la disposition
; de la mémoire, les permissions (lecture/écriture/exécution) et les métadonnées.
;
; Quand tu compiles un fichier .asm en .o puis en binaire, NASM génère des
; sections ELF, et le linker (ld) les organise en segments pour l’exécution.
;
; NASM (Netwide Assembler)
; ------------------------
; NASM est un assembleur libre pour la syntaxe Intel (plus lisible que AT&T).
; Il transforme ton code assembleur en instructions machines et gère :
;   - les sections (via la directive SECTION)
;   - les déclarations de données (db, dw, dd, dq…)
;   - les symboles
;   - les relocalisations utilisées par le linker
;
; En résumé :
;   NASM assemble → ld linke → ELF exécute.
;
;
; ---------------------------------------------------------------------------
; SECTIONS ELF (.text, .data, .bss) — À QUOI ÇA SERT ?
;
; En assembleur x86_64 sous Linux, un programme est structuré en *sections* :
;
;   .text  → contient le code machine (instructions exécutables)
;   .data  → contient les données initialisées (chaînes, nombres, constantes…)
;   .bss   → contient les données non initialisées (buffers, variables remplies à 0)
;
; Une *section* n’est pas spécifique à NASM : elle fait partie du standard ELF.
; NASM se contente de remplir ces sections, et ld (le linker) les regroupe dans
; les segments mémoire adéquats lors de la création du binaire final.
;
;
; SECTION .data
; -------------
; `.data` contient les données **déjà connues à la compilation**.
; On y place par exemple :
;
;   db "texte", 0      ; bytes
;   dd 123             ; entier 32 bits
;   dq 1234567890123   ; entier 64 bits
;
; Lors du chargement du programme, le loader place ces données dans une zone
; mémoire en lecture/écriture (RW) pré-initialisée.
;
;
; Références officielles NASM :
; -----------------------------
; Déclaration des données (db, dw, dd, dq — "initialized data") :
;   https://www.nasm.us/doc/nasm03.html#section-3.2.1
;
; Directive SECTION (définition des sections ELF) :
;   https://www.nasm.us/doc/nasmdoc5.html#section-5.3
;
; ---------------------------------------------------------------------------
section .data
    ; ---------------------------------------------------------------------------
    ; response :
    ; Définit une suite d’octets initialisés dans la section .data.
    ; 'db' (define byte) stocke chaque caractère du JSON en ASCII, puis ajoute
    ; l’octet 10 à la fin (0x0A = saut de ligne '\n').
    ; Le label 'response' pointe sur le début de cette zone mémoire.
    ;
    ; response_len :
    ; 'equ' crée une constante égale à l’expression ($ - response).
    ; - '$' représente l’adresse courante (juste après les données).
    ; - 'response' est l’adresse du début de la chaîne.
    ; Leur différence donne la longueur exacte de la réponse en octets.
    ; ---------------------------------------------------------------------------
    response db '{"ideas":["Console de jeux","Casque audio","Smartphone","Montre connectee","Abonnement streaming"]}', 10
    response_len equ $ - response

; ---------------------------------------------------------------------------
; SECTION .text :
; Cette section contient le code exécutable du programme. Dans le format ELF
; (Linux), le linker place .text dans un segment marqué comme "exécutable".
; Toutes les instructions machine (assembleur compilé) sont définies ici.
;
; global _start :
; La directive 'global' exporte un symbole pour le linker.
; Ici, elle indique que le label '_start' doit être visible en dehors du
; fichier objet et servir de point d’entrée du programme.
;
; Contrairement à un programme C, il n’y a pas de fonction 'main' en assembleur.
; Le kernel commence l’exécution exactement à l’adresse du symbole '_start'.
; ---------------------------------------------------------------------------
section .text
    global _start

_start:
    ; Appel système write(1, response, response_len)
    ; -----------------------------------------------------------
    ; Linux utilise les registres pour recevoir les arguments :
    ;   rax = numéro du syscall
    ;   rdi = 1er argument
    ;   rsi = 2e argument
    ;   rdx = 3e argument
    ;
    ; Ici, on prépare un appel au syscall write :
    ;   write(fd=1, buffer=response, length=response_len)
    ;
    mov rax, 1            ; 1 = numéro du syscall 'write'
    mov rdi, 1            ; fd = 1 → stdout (affichage console)
    mov rsi, response     ; adresse du buffer à écrire
    mov rdx, response_len ; nombre d’octets à écrire
    syscall               ; appel le kernel → effectue write()

    ; Appel système exit(0)
    ; -----------------------------------------------------------
    ; Pour terminer proprement un programme en assembleur,
    ; on doit appeler le syscall 'exit'.
    ;
    ; Linux attend :
    ;   rax = numéro du syscall (60 = exit)
    ;   rdi = code de retour (0 = succès)
    ;
    mov rax, 60  ; 60 = syscall 'exit'
    xor rdi, rdi ; place 0 dans rdi (code retour), plus rapide que mov rdi,0
    syscall      ; appel le kernel → termine immédiatement le programme
