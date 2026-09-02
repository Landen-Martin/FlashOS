[org 0x7c00]

; Set up segment registers and stack
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00

; 1. Clear the screen
clear_screen:
    mov ah, 0x06        ; scroll up
    mov al, 0           ; number of lines to scroll (0 = clear entire window)
    mov bh, 0x07        ; attribute (light grey on black)
    mov cx, 0           ; upper-left corner (row=0, col=0)
    mov dx, 0x184f      ; lower-right corner (row=24, col=79) for 80x25 text mode
    int 0x10

    ; (Optional) Set cursor to top-left (row=0, col=0)
    mov ah, 0x02
    mov bh, 0           ; page 0
    mov dx, 0           ; DH=row, DL=col
    int 0x10

; 2. Print the message using teletype output
mov si, msg
print_loop:
    lodsb
    test al, al
    jz done
    mov ah, 0x0e
    int 0x10
    jmp print_loop

done:
    cli
    hlt
    jmp done

msg db "Hello, World!", 0

; Boot signature
times 510 - ($ - $$) db 0
dw 0xaa55