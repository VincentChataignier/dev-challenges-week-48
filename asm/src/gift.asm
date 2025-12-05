; =============================================================================
; src/gift.asm - Gift ideas generator business logic
; =============================================================================
; All functions use 'gift_' prefix to avoid naming collisions
;
; Exported functions:
;   gift_read_input       - Read JSON from stdin
;   gift_parse_json       - Parse age and interests from JSON
;   gift_build_prompt     - Build prompt for Ollama
;   gift_connect_ollama   - Create socket and connect
;   gift_send_request     - Build and send HTTP request
;   gift_read_response    - Read HTTP response
;   gift_output_result    - Parse response and output JSON
; =============================================================================

%include "include/constants.inc"
%include "include/data.inc"

; -----------------------------------------------------------------------------
; External functions
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
extern mem_alloc
extern mem_free

section .text

; -----------------------------------------------------------------------------
; gift_init: Allocate dynamic buffers (call before using gift_* functions)
; Output: rax = 1 on success, 0 on allocation failure
; -----------------------------------------------------------------------------
global gift_init
gift_init:
    push rbx

    ; Allocate response_buffer (64 KB)
    mov rdi, RESPONSE_SIZE
    call mem_alloc
    test rax, rax
    jz .alloc_failed
    mov [response_buffer_ptr], rax

    ; Allocate http_request buffer (16 KB)
    mov rdi, HTTP_REQ_SIZE
    call mem_alloc
    test rax, rax
    jz .alloc_failed_cleanup
    mov [http_request_ptr], rax

    mov rax, 1                  ; Success
    pop rbx
    ret

.alloc_failed_cleanup:
    ; Free response_buffer if http_request alloc failed
    mov rdi, [response_buffer_ptr]
    mov rsi, RESPONSE_SIZE
    call mem_free

.alloc_failed:
    xor rax, rax
    pop rbx
    ret

; -----------------------------------------------------------------------------
; gift_cleanup: Free dynamic buffers (call when done)
; -----------------------------------------------------------------------------
global gift_cleanup
gift_cleanup:
    ; Free response_buffer
    mov rdi, [response_buffer_ptr]
    test rdi, rdi
    jz .skip_response
    mov rsi, RESPONSE_SIZE
    call mem_free
    mov qword [response_buffer_ptr], 0

.skip_response:
    ; Free http_request
    mov rdi, [http_request_ptr]
    test rdi, rdi
    jz .skip_http
    mov rsi, HTTP_REQ_SIZE
    call mem_free
    mov qword [http_request_ptr], 0

.skip_http:
    ret

; -----------------------------------------------------------------------------
; gift_read_input: Read JSON from stdin into input_buffer
; Output: rax = bytes read (0 on error)
; -----------------------------------------------------------------------------
global gift_read_input
gift_read_input:
    mov rax, SYS_READ
    mov rdi, STDIN
    lea rsi, [input_buffer]
    mov rdx, INPUT_SIZE - 1
    syscall

    ; Check for read error
    test rax, rax
    js .error
    jz .error

    ; Save length
    mov [input_len], rax

    ; Null-terminate
    lea rdi, [input_buffer]
    add rdi, rax
    mov byte [rdi], 0

    ret

.error:
    xor rax, rax
    ret

; -----------------------------------------------------------------------------
; gift_parse_json: Parse "age" and "interests" from input JSON
; Output: rax = 1 on success, 0 on error
; -----------------------------------------------------------------------------
global gift_parse_json
gift_parse_json:
    push r12

    ; Find "age":
    lea rdi, [input_buffer]
    lea rsi, [key_age]
    mov rdx, key_age_len
    call str_find
    test rax, rax
    jz .error

    ; Extract number after "age":
    lea rdi, [rax]
    lea rsi, [age_buffer]
    call json_extract_number
    test rax, rax
    jz .error

    ; Validate age > 0
    lea rsi, [age_buffer]
    call str_to_int
    test rax, rax
    jz .error

    ; Find "interests":
    lea rdi, [input_buffer]
    lea rsi, [key_interests]
    mov rdx, key_interests_len
    call str_find
    test rax, rax
    jz .error

    ; Extract string after "interests":
    lea rdi, [rax]
    lea rsi, [interests_buffer]
    call json_extract_string
    test rax, rax
    jz .error

    mov rax, 1
    pop r12
    ret

.error:
    xor rax, rax
    pop r12
    ret

; -----------------------------------------------------------------------------
; gift_build_prompt: Build prompt string from age and interests
; Output: prompt_buffer contains the built prompt
; -----------------------------------------------------------------------------
global gift_build_prompt
gift_build_prompt:
    lea rdi, [prompt_buffer]

    ; Copy prefix ("Age: ")
    lea rsi, [prompt_prefix]
    mov rcx, prompt_prefix_len
    call str_copy_mem

    ; Copy age value
    lea rsi, [age_buffer]
    call str_copy

    ; Copy middle (". Gouts: ")
    lea rsi, [prompt_middle]
    mov rcx, prompt_middle_len
    call str_copy_mem

    ; Copy interests
    lea rsi, [interests_buffer]
    call str_copy

    ; Copy suffix
    lea rsi, [prompt_suffix]
    mov rcx, prompt_suffix_len
    call str_copy_mem

    ; Null-terminate
    mov byte [rdi], 0

    ret

; -----------------------------------------------------------------------------
; gift_connect_ollama: Create TCP socket and connect to Ollama
; Output: rax = 1 on success, 0 on connect error, negative on socket error
; -----------------------------------------------------------------------------
global gift_connect_ollama
gift_connect_ollama:
    ; Create socket
    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx                ; protocol = 0
    syscall

    test rax, rax
    js .socket_error

    mov [socket_fd], rax

    ; Connect to Ollama
    mov rax, SYS_CONNECT
    mov rdi, [socket_fd]
    lea rsi, [sockaddr]
    mov rdx, sockaddr_len
    syscall

    test rax, rax
    jnz .connect_error

    mov rax, 1                  ; Success
    ret

.socket_error:
    ret                         ; rax is already negative

.connect_error:
    xor rax, rax
    ret

; -----------------------------------------------------------------------------
; gift_send_request: Build and send HTTP request to Ollama
; Output: rax = bytes sent (negative on error)
; Uses: http_request_ptr (dynamically allocated)
; -----------------------------------------------------------------------------
global gift_send_request
gift_send_request:
    push r12
    push r13
    push r14
    push r15
    push rbx

    mov rbx, [http_request_ptr] ; rbx = http_request buffer base

    ; Build JSON body first to calculate actual size (after escaping)
    mov rdi, rbx
    add rdi, 512                ; Offset to leave room for headers
    mov r14, rdi                ; Save body start

    ; Copy body start
    lea rsi, [http_body_start]
    mov rcx, http_body_start_len
    call str_copy_mem

    ; Copy prompt (with escaping)
    lea rsi, [prompt_buffer]
    call str_copy_escaped

    ; Copy body end
    lea rsi, [http_body_end]
    mov rcx, http_body_end_len
    call str_copy_mem

    ; Calculate body size
    mov rax, rdi
    sub rax, r14                ; rax = actual body size
    push rax                    ; Save body size
    push rdi                    ; Save body end

    ; Convert size to string
    lea rdi, [content_len_str]
    call str_from_int
    mov r13, rax                ; r13 = Content-Length string length

    ; Now build the actual HTTP request
    mov rdi, rbx                ; Start of http_request buffer

    ; Copy headers
    lea rsi, [http_post]
    mov rcx, http_post_len
    call str_copy_mem

    ; Copy Content-Length value
    lea rsi, [content_len_str]
    mov rcx, r13
    call str_copy_mem

    ; Add \r\n\r\n
    lea rsi, [crlf2]
    mov rcx, crlf2_len
    call str_copy_mem

    ; Copy the body we built above
    pop r15                     ; Body end
    pop rcx                     ; Body size
    mov rsi, r14                ; Body start (at offset 512)
    call str_copy_mem

    ; Calculate total request size
    mov rax, rbx
    sub rdi, rax
    mov r14, rdi                ; r14 = request size

    ; Send request
    mov rax, SYS_WRITE
    mov rdi, [socket_fd]
    mov rsi, rbx                ; http_request buffer
    mov rdx, r14
    syscall

    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; -----------------------------------------------------------------------------
; gift_read_response: Read HTTP response from socket
; Output: rax = bytes read (0 on error)
; Uses: response_buffer_ptr (dynamically allocated)
; -----------------------------------------------------------------------------
global gift_read_response
gift_read_response:
    push r14
    push r15

    mov r15, [response_buffer_ptr]  ; Current pointer (dynamic buffer)
    xor r14, r14                    ; Total bytes read

.read_loop:
    mov rax, SYS_READ
    mov rdi, [socket_fd]
    mov rsi, r15
    mov rdx, RESPONSE_SIZE
    sub rdx, r14                ; Remaining space
    jz .read_done               ; Buffer full
    syscall

    test rax, rax
    jle .read_done              ; EOF or error

    add r14, rax                ; Add to total
    add r15, rax                ; Advance pointer
    jmp .read_loop

.read_done:
    ; Close socket
    mov rax, SYS_CLOSE
    mov rdi, [socket_fd]
    syscall

    ; Null-terminate
    mov byte [r15], 0

    mov rax, r14                ; Return total bytes

    pop r15
    pop r14
    ret

; -----------------------------------------------------------------------------
; gift_output_result: Parse response and output JSON to stdout
; Output: rax = 1 on success, 0 on error
; Uses: response_buffer_ptr (dynamically allocated)
; -----------------------------------------------------------------------------
global gift_output_result
gift_output_result:
    push r12

    ; Find "response":"..." in HTTP response
    mov rdi, [response_buffer_ptr]
    lea rsi, [key_response]
    mov rdx, key_response_len
    call str_find
    test rax, rax
    jz .error

    ; Find {"ideas":[...]} JSON in response
    mov rdi, rax
    call json_find_ideas
    test rax, rax
    jz .error

    ; rax = JSON start, rdx = length
    mov rsi, rax
    mov r12, rdx

    ; Unescape JSON
    lea rdi, [output_buffer]
    call json_unescape
    ; rax = unescaped length

    ; Write to stdout
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [output_buffer]
    syscall

    ; Add newline
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [crlf]
    mov rdx, crlf_len
    syscall

    mov rax, 1                  ; Success
    pop r12
    ret

.error:
    xor rax, rax
    pop r12
    ret
