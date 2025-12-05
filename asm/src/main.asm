; =============================================================================
; main.asm - Program entry point
; =============================================================================
; Gift Ideas Generator - Pure ASM x86_64
; Reads JSON from stdin, calls Ollama via TCP socket, returns gift ideas
;
; Build:
;   make
;
; Usage:
;   echo '{"age": 25, "interests": "gaming"}' | ./gift_core
; =============================================================================

%include "include/constants.inc"
%include "include/data.inc"

; -----------------------------------------------------------------------------
; External functions from lib/
; -----------------------------------------------------------------------------
extern str_copy_mem
extern str_copy
extern str_copy_escaped
extern str_to_int
extern str_from_int
extern str_find
extern json_extract_number
extern json_extract_string
extern json_find_ideas
extern json_unescape

; -----------------------------------------------------------------------------
; External functions from src/gift.asm
; -----------------------------------------------------------------------------
extern gift_init
extern gift_cleanup
extern gift_read_input
extern gift_parse_json
extern gift_build_prompt
extern gift_connect_ollama
extern gift_send_request
extern gift_read_response
extern gift_output_result

; =============================================================================
; SECTION .text - Executable code
; =============================================================================
section .text
    global _start

; =============================================================================
; ENTRY POINT
; =============================================================================
_start:
    ; -------------------------------------------------------------------------
    ; Allocate dynamic buffers
    ; -------------------------------------------------------------------------
    call gift_init
    test rax, rax
    jz .error_alloc

    ; -------------------------------------------------------------------------
    ; Read JSON input from stdin
    ; -------------------------------------------------------------------------
    call gift_read_input
    test rax, rax
    jz .error_json

    ; -------------------------------------------------------------------------
    ; Parse JSON - extract "age" and "interests"
    ; -------------------------------------------------------------------------
    call gift_parse_json
    test rax, rax
    jz .error_json

    ; -------------------------------------------------------------------------
    ; Build prompt for Ollama
    ; -------------------------------------------------------------------------
    call gift_build_prompt

    ; -------------------------------------------------------------------------
    ; Create socket and connect to Ollama
    ; -------------------------------------------------------------------------
    call gift_connect_ollama
    test rax, rax
    js .error_socket
    jz .error_connect

    ; -------------------------------------------------------------------------
    ; Build and send HTTP request
    ; -------------------------------------------------------------------------
    call gift_send_request
    test rax, rax
    js .error_socket

    ; -------------------------------------------------------------------------
    ; Read HTTP response
    ; -------------------------------------------------------------------------
    call gift_read_response
    test rax, rax
    jz .error_response

    ; -------------------------------------------------------------------------
    ; Parse response and output result
    ; -------------------------------------------------------------------------
    call gift_output_result
    test rax, rax
    jz .error_response

    ; Success!
    xor rdi, rdi
    jmp .exit

; -----------------------------------------------------------------------------
; ERROR HANDLERS
; -----------------------------------------------------------------------------
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
    jmp .cleanup

.error_alloc:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    lea rsi, [err_alloc]
    mov rdx, err_alloc_len
    syscall
    mov rdi, EXIT_RUNTIME_ERR
    jmp .exit_now               ; Skip cleanup, nothing allocated

.cleanup:
    ; Free dynamically allocated buffers
    push rdi                    ; Save exit code
    call gift_cleanup
    pop rdi                     ; Restore exit code
    jmp .exit_now

.exit:
    ; Normal exit with cleanup
    push rdi
    call gift_cleanup
    pop rdi

.exit_now:
    mov rax, SYS_EXIT
    syscall
