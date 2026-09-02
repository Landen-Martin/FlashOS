; init.asm
[org 0x7E00]
bits 16

start_init:
    ; Enable A20
    mov ax, 0x2401
    int 0x15
    jc .a20_kbd
    jmp .a20_done

.a20_kbd:
    cli
    call .wait_kbd_write
    mov al, 0xAD
    out 0x64, al
    call .wait_kbd_write
    mov al, 0xD0
    out 0x64, al
    call .wait_kbd_read
    in al, 0x60
    push ax
    call .wait_kbd_write
    mov al, 0xD1
    out 0x64, al
    call .wait_kbd_write
    pop ax
    or al, 0x02
    out 0x60, al
    call .wait_kbd_write
    mov al, 0xAE
    out 0x64, al
    sti

.a20_done:
    ; Load GDT
    lgdt [gdt_desc]

    ; Enable Protected Mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Far jump to 32-bit code at 0x08:0x8000
    jmp 0x08:0x8000

; Helper routines for keyboard controller
.wait_kbd_write:
    in al, 0x64
    test al, 0x02
    jnz .wait_kbd_write
    ret

.wait_kbd_read:
    in al, 0x64
    test al, 0x01
    jz .wait_kbd_read
    ret

; ---- GDT (flat 32-bit segments) ----
gdt_start:
    dq 0                    ; null descriptor

gdt_code:
    dw 0xFFFF               ; limit low
    dw 0x0000               ; base low
    db 0x00                 ; base mid
    db 10011010b            ; access (present, ring0, code, executable, readable)
    db 11001111b            ; granularity (4KB, 32-bit, limit high)
    db 0x00                 ; base high

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b            ; access (present, ring0, data, read/write)
    db 11001111b
    db 0x00
    
gdt_end:
gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; pad this sector to 512 bytes
times 512 - ($ - $$) db 0