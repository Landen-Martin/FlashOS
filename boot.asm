; boot.asm
[org 0x7c00]
bits 16

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00          ; stack just below boot sector

    ; --- Read kernel from disk (sectors 2..9) into 0x8000 ---
    mov bx, 0x0000
    mov es, bx
    mov bx, 0x8000          ; ES:BX = 0x0000:0x8000
    mov ah, 0x02            ; read sectors
    mov al, 8               ; read 8 sectors (4 KB) – adjust if kernel is larger
    mov ch, 0               ; cylinder 0
    mov cl, 2               ; sector 2 (LBA 1)
    mov dh, 0               ; head 0
    ; DL still contains boot drive number
    int 0x13
    jc disk_error

    ; --- Enable A20 ---
    mov ax, 0x2401
    int 0x15
    jnc .a20_done
    ; fallback to keyboard controller
    call enable_a20_kbd

.a20_done:
    ; --- Load GDT ---
    lgdt [gdt_desc]

    ; --- Switch to protected mode ---
    cli                     ; disable interrupts (important!)
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; --- Far jump to 32-bit kernel at 0x08:0x8000 ---
    jmp 0x08:0x8000

; ---------------------------------------------------------------------------
; Disk error handler
disk_error:
    mov si, err_msg
    call print_string
    cli
    hlt
    jmp $

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

; ---------------------------------------------------------------------------
; A20 via keyboard controller
enable_a20_kbd:
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
    ret

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

; ---------------------------------------------------------------------------
; GDT (flat 32-bit segments)
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

; ---------------------------------------------------------------------------
err_msg db "Disk read error!", 0

times 510 - ($ - $$) db 0
dw 0xaa55