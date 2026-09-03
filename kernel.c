/* kernel.c */
void kernel_main() {
    volatile unsigned char *vga = (unsigned char *)0xB8000;
    const char *msg = "Hello, World!";
    int i = 0;

    // Clear screen (80x25, white on black)
    for (int pos = 0; pos < 80 * 25; pos++) {
        vga[pos * 2] = ' ';
        vga[pos * 2 + 1] = 0x07;
    }

    // Print message
    while (msg[i] != '\0') {
        vga[i * 2] = msg[i];
        vga[i * 2 + 1] = 0x0F;   // bright white on black
        i++;
    }

    // Halt
    for (;;) {
        __asm__ volatile ("hlt");
    }
}

// Entry point expected by boot loader (first function in binary)
void _start() __attribute__((section(".text.startup"), noreturn));
void _start() {
    kernel_main();
    __builtin_unreachable();
}