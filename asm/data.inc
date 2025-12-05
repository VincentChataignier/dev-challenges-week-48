; data.inc - Sections .data et .bss pour gift_core
; ===========================================================================

section .data

; ---------------------------------------------------------------------------
; Structure sockaddr_in pour Ollama (127.0.0.1:11434)
; Format: sin_family (2) + sin_port (2) + sin_addr (4) + padding (8) = 16 bytes
; ---------------------------------------------------------------------------
sockaddr:
    dw AF_INET              ; sin_family = AF_INET (2 bytes)
    dw 0xAA2C               ; sin_port = 11434 en big-endian (0x2CAA -> 0xAA2C)
    dd 0x0100007F           ; sin_addr = 127.0.0.1 en big-endian
    dq 0                    ; padding (8 bytes)
sockaddr_len equ 16

; ---------------------------------------------------------------------------
; Templates HTTP
; ---------------------------------------------------------------------------
http_post db "POST /api/generate HTTP/1.1", 13, 10
          db "Host: 127.0.0.1:11434", 13, 10
          db "Content-Type: application/json", 13, 10
          db "Connection: close", 13, 10
          db "Content-Length: "
http_post_len equ $ - http_post

http_body_start db '{"model":"qwen2.5:3b","prompt":"'
http_body_start_len equ $ - http_body_start

http_body_end db '","stream":false,"format":"json"}'
http_body_end_len equ $ - http_body_end

crlf db 13, 10
crlf2 db 13, 10, 13, 10

; ---------------------------------------------------------------------------
; Template du prompt (format JSON strict)
; ---------------------------------------------------------------------------
prompt_prefix db "Age: "
prompt_prefix_len equ $ - prompt_prefix

prompt_middle db ". Gouts: "
prompt_middle_len equ $ - prompt_middle

prompt_suffix db '. Genere 5 noms de cadeaux. Format EXACT: {"ideas":["Cadeau1","Cadeau2","Cadeau3","Cadeau4","Cadeau5"]} RIEN DAUTRE. Pas de description, pas de markdown, juste ce JSON.'
prompt_suffix_len equ $ - prompt_suffix

; ---------------------------------------------------------------------------
; Messages d'erreur
; ---------------------------------------------------------------------------
err_json db "Invalid JSON input", 10
err_json_len equ $ - err_json

err_socket db "Socket error", 10
err_socket_len equ $ - err_socket

err_connect db "Connection error", 10
err_connect_len equ $ - err_connect

err_response db "Invalid response", 10
err_response_len equ $ - err_response

; ---------------------------------------------------------------------------
; Clés JSON à chercher
; ---------------------------------------------------------------------------
key_age db '"age":'
key_age_len equ $ - key_age

key_interests db '"interests":'
key_interests_len equ $ - key_interests

key_response db '"response":"'
key_response_len equ $ - key_response

; ===========================================================================
; SECTION BSS - Données non initialisées
; ===========================================================================
section .bss

input_buffer    resb INPUT_SIZE         ; Buffer pour stdin
input_len       resq 1                  ; Longueur lue depuis stdin
response_buffer resb RESPONSE_SIZE      ; Buffer pour réponse HTTP
http_request    resb HTTP_REQ_SIZE      ; Buffer pour requête HTTP
prompt_buffer   resb PROMPT_SIZE        ; Buffer pour le prompt
age_buffer      resb 16                 ; Buffer pour l'âge (string)
interests_buffer resb 512               ; Buffer pour les intérêts
socket_fd       resq 1                  ; File descriptor du socket
content_len_str resb 16                 ; Content-Length en string
output_buffer   resb 4096               ; Buffer pour JSON unescaped