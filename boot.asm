; boot.asm
[org 0x7c00]
bits 16

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; read 2 sectors (init and main) starting from LBA 1 into 0x7E00
    mov bx, 0x0000
    mov es, bx
    mov bx, 0x7E00      ; ES:BX = 0x0000:0x7E00
    mov ah, 0x02        ; read sectors
    mov al, 2           ; read 2 sectors
    mov ch, 0           ; cylinder 0
    mov cl, 2           ; sector 2 (LBA 1 -> CHS: cylinder 0, head 0, sector 2)
    mov dh, 0           ; head 0

    ; DL already contains boot drive
    int 0x13
    jc disk_error

    ; jump to init at 0x7E00
    jmp 0x0000:0x7E00

disk_error:
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
times 510 - ($ - $$) db 0
dw 0xaa55