; =============================================================================
; data.inc - Data sections (.data and .bss) for gift_core
; =============================================================================
; Usage: %include "include/data.inc"
; Requires: constants.inc to be included first
; =============================================================================

%ifndef DATA_INC
%define DATA_INC

; =============================================================================
; SECTION .data - Initialized data
; =============================================================================
section .data

; -----------------------------------------------------------------------------
; sockaddr_in structure for Ollama (127.0.0.1:11434)
; Format: sin_family (2) + sin_port (2) + sin_addr (4) + padding (8) = 16 bytes
; -----------------------------------------------------------------------------
sockaddr:
    dw AF_INET              ; sin_family = AF_INET (2 bytes)
    dw 0xAA2C               ; sin_port = 11434 big-endian (0x2CAA -> 0xAA2C)
    db 127,0,0,1            ; sin_addr = 127.0.0.1
    dq 0                    ; padding (8 bytes)
sockaddr_len equ 16

; -----------------------------------------------------------------------------
; HTTP templates
; -----------------------------------------------------------------------------
http_post:
    db "POST /api/generate HTTP/1.1", CRLF
    db "Host: 127.0.0.1:11434", CRLF
    db "Content-Type: application/json", CRLF
    db "Connection: close", CRLF
    db "Content-Length: "
http_post_len equ $ - http_post

http_body_start     db '{"model":"qwen2.5:3b","prompt":"'
http_body_start_len equ $ - http_body_start

http_body_end     db '","stream":false,"format":"json"}'
http_body_end_len equ $ - http_body_end

crlf      db CRLF
crlf_len  equ 2
crlf2     db CRLF, CRLF
crlf2_len equ 4

; -----------------------------------------------------------------------------
; Prompt template (strict JSON format)
; -----------------------------------------------------------------------------
prompt_prefix     db "Age: "
prompt_prefix_len equ $ - prompt_prefix

prompt_middle     db ". Gouts: "
prompt_middle_len equ $ - prompt_middle

prompt_suffix     db '. Genere 5 noms de cadeaux. Format EXACT: {"ideas":["Cadeau1","Cadeau2","Cadeau3","Cadeau4","Cadeau5"]} RIEN DAUTRE. Pas de description, pas de markdown, juste ce JSON.'
prompt_suffix_len equ $ - prompt_suffix

; -----------------------------------------------------------------------------
; Error messages
; -----------------------------------------------------------------------------
err_json     db "Error: Invalid JSON input", 10
err_json_len equ $ - err_json

err_socket     db "Error: Socket creation failed", 10
err_socket_len equ $ - err_socket

err_connect     db "Error: Connection failed", 10
err_connect_len equ $ - err_connect

err_response     db "Error: Invalid response", 10
err_response_len equ $ - err_response

err_alloc     db "Error: Memory allocation failed", 10
err_alloc_len equ $ - err_alloc

; -----------------------------------------------------------------------------
; JSON keys to search
; -----------------------------------------------------------------------------
key_age     db '"age":'
key_age_len equ $ - key_age

key_interests     db '"interests":'
key_interests_len equ $ - key_interests

key_response     db '"response":"'
key_response_len equ $ - key_response

; =============================================================================
; SECTION .bss - Uninitialized data
; =============================================================================
section .bss

; -----------------------------------------------------------------------------
; Small static buffers (kept in .bss - always allocated)
; Total: ~10.5 KB
; -----------------------------------------------------------------------------
input_buffer     resb INPUT_SIZE         ; stdin buffer (4 KB)
input_len        resq 1                  ; Length read from stdin
prompt_buffer    resb PROMPT_SIZE        ; Prompt buffer (2 KB)
age_buffer       resb 16                 ; Age string buffer
interests_buffer resb 512                ; Interests buffer
socket_fd        resq 1                  ; Socket file descriptor
content_len_str  resb 16                 ; Content-Length as string
output_buffer    resb 4096               ; Unescaped JSON buffer (4 KB)

; -----------------------------------------------------------------------------
; Pointers to dynamically allocated buffers (allocated on demand)
; Saves: ~80 KB when not in use
; -----------------------------------------------------------------------------
response_buffer_ptr resq 1               ; -> response buffer (64 KB via mmap)
http_request_ptr    resq 1               ; -> HTTP request buffer (16 KB via mmap)

%endif ; DATA_INC
