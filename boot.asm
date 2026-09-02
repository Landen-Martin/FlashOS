[org 0x7c00]
bits 16

start:
    ; Set up segment registers and stack
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Clear the screen
    mov ah, 0x06
    xor al, al
    mov bh, 0x07
    mov cx, 0
    mov dx, 0x184f
    int 0x10
    mov ah, 0x02
    mov bh, 0
    mov dx, 0
    int 0x10

    ; Load the kernel into memory at 0x0000:0x7E00
    mov bx, 0x0000
    mov es, bx
    mov bx, 0x7E00          ; ES:BX = target address
    mov ah, 0x02            ; BIOS read sectors function
    mov al, 1               ; number of sectors to read (adjust if kernel grows)
    mov ch, 0               ; cylinder 0
    mov cl, 2               ; sector number (LBA 1 - CHS: cylinder 0, head 0, sector 2)
    mov dh, 0               ; head 0

    ; DL already contains the boot drive number (passed by BIOS) - we keep it
    int 0x13
    jc error           ; if carry set, error

    ; Jump to the loaded kernel
    jmp 0x0000:0x7E00

; disk error
error:
    mov si, err_msg
    call print
    cli
    hlt
    jmp $

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print

.done:
    ret

err_msg db "Disk read error!", 0

; Boot sector signature
times 510 - ($ - $$) db 0
dw 0xaa55