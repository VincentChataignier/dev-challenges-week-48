; =============================================================================
; lib/memory.asm - Dynamic memory allocation functions
; =============================================================================
; All functions use 'mem_' prefix to avoid naming collisions
;
; Exported functions:
;   mem_alloc     - Allocate memory using mmap
;   mem_free      - Free memory using munmap
; =============================================================================

section .text

; Syscall numbers
SYS_MMAP    equ 9
SYS_MUNMAP  equ 11

; mmap constants
PROT_READ     equ 0x1
PROT_WRITE    equ 0x2
MAP_PRIVATE   equ 0x02
MAP_ANONYMOUS equ 0x20

; -----------------------------------------------------------------------------
; mem_alloc: Allocate memory dynamically
; Input:  rdi = size in bytes
; Output: rax = pointer to allocated memory, or 0 on failure
; -----------------------------------------------------------------------------
global mem_alloc
mem_alloc:
    push rdi                    ; Save size for later

    ; mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
    mov rsi, rdi                ; size
    xor rdi, rdi                ; addr = NULL (let kernel choose)
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1                  ; fd = -1 (no file)
    xor r9, r9                  ; offset = 0
    mov rax, SYS_MMAP
    syscall

    pop rdi

    ; Check for error (mmap returns -1 on failure, or address < 0xFFFFFFFFFFFF000)
    cmp rax, -4096
    ja .error
    ret

.error:
    xor rax, rax                ; Return NULL on error
    ret

; -----------------------------------------------------------------------------
; mem_free: Free dynamically allocated memory
; Input:  rdi = pointer to memory, rsi = size
; Output: rax = 0 on success, -1 on failure
; -----------------------------------------------------------------------------
global mem_free
mem_free:
    mov rax, SYS_MUNMAP
    syscall
    ret
