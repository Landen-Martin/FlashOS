[org 0x7E00]
bits 16

start:
    mov si, msg
    call print

    cli
    hlt
    jmp $

; output "Hello, World!"
print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print

.done:
    ret

; The message:
msg db "Hello, World!", 0
times 512 - ($ - $$) db 0