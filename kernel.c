/* kernel.c – Echo shell with VGA text mode output and PS/2 keyboard input */

#define VGA_MEMORY 0xB8000
#define VGA_WIDTH  80
#define VGA_HEIGHT 25

/* Cursor position */
static int cursor_x = 0;
static int cursor_y = 0;

/* Keyboard state */
static int shift_pressed = 0;

/* Input buffer */
static char input_buffer[256];
static int input_len = 0;

/* ---------------------------------------------------------------------------
 * I/O port functions (needed for keyboard and other hardware access)
 * ------------------------------------------------------------------------- */

static inline unsigned char inb(unsigned short port) {
    unsigned char result;
    __asm__ volatile ("inb %1, %0" : "=a"(result) : "Nd"(port));
    return result;
}

static inline void outb(unsigned short port, unsigned char data) {
    __asm__ volatile ("outb %0, %1" : : "a"(data), "Nd"(port));
}

/* ---------------------------------------------------------------------------
 * VGA text output functions
 * ------------------------------------------------------------------------- */

static inline void vga_putchar_at(int x, int y, char c, unsigned char color) {
    volatile unsigned char *vga = (unsigned char *)VGA_MEMORY;
    int index = (y * VGA_WIDTH + x) * 2;
    vga[index] = c;
    vga[index + 1] = color;
}

static void vga_putchar(char c) {
    if (c == '\n') {
        cursor_x = 0;
        cursor_y++;
        if (cursor_y >= VGA_HEIGHT) {
            /* Simple scroll: move everything up one line */
            volatile unsigned short *vga = (unsigned short *)VGA_MEMORY;
            for (int y = 0; y < VGA_HEIGHT - 1; y++) {
                for (int x = 0; x < VGA_WIDTH; x++) {
                    vga[y * VGA_WIDTH + x] = vga[(y + 1) * VGA_WIDTH + x];
                }
            }
            /* Clear last line */
            for (int x = 0; x < VGA_WIDTH; x++) {
                vga_putchar_at(x, VGA_HEIGHT - 1, ' ', 0x07);
            }
            cursor_y = VGA_HEIGHT - 1;
        }
        return;
    }
    if (c == '\b') {
        if (cursor_x > 0) {
            cursor_x--;
            vga_putchar_at(cursor_x, cursor_y, ' ', 0x07);
        } else if (cursor_y > 0) {
            cursor_y--;
            cursor_x = VGA_WIDTH - 1;
            vga_putchar_at(cursor_x, cursor_y, ' ', 0x07);
        }
        return;
    }
    /* Printable character */
    vga_putchar_at(cursor_x, cursor_y, c, 0x0F); /* bright white on black */
    cursor_x++;
    if (cursor_x >= VGA_WIDTH) {
        cursor_x = 0;
        cursor_y++;
        if (cursor_y >= VGA_HEIGHT) {
            /* Scroll as above */
            volatile unsigned short *vga = (unsigned short *)VGA_MEMORY;
            for (int y = 0; y < VGA_HEIGHT - 1; y++) {
                for (int x = 0; x < VGA_WIDTH; x++) {
                    vga[y * VGA_WIDTH + x] = vga[(y + 1) * VGA_WIDTH + x];
                }
            }
            for (int x = 0; x < VGA_WIDTH; x++) {
                vga_putchar_at(x, VGA_HEIGHT - 1, ' ', 0x07);
            }
            cursor_y = VGA_HEIGHT - 1;
        }
    }
}

static void vga_print(const char *str) {
    while (*str) {
        vga_putchar(*str++);
    }
}

static void vga_clear_screen(void) {
    for (int y = 0; y < VGA_HEIGHT; y++) {
        for (int x = 0; x < VGA_WIDTH; x++) {
            vga_putchar_at(x, y, ' ', 0x07);
        }
    }
    cursor_x = 0;
    cursor_y = 0;
}

/* ---------------------------------------------------------------------------
 * PS/2 keyboard input (polling)
 * ------------------------------------------------------------------------- */

#define KEY_BACKSPACE 0x0E
#define KEY_ENTER     0x1C
#define KEY_LSHIFT    0x2A
#define KEY_RSHIFT    0x36
#define KEY_BREAK     0x80

/* US keyboard scan code set 1 -> ASCII (normal, shifted) */
static const char keymap_normal[] = {
    /* 0x00 */ 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b', '\t',
    /* 0x10 */ 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', 0, 'a', 's',
    /* 0x20 */ 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0, '\\', 'z', 'x', 'c', 'v',
    /* 0x30 */ 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0,
    /* 0x40 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    /* 0x50 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

static const char keymap_shifted[] = {
    /* 0x00 */ 0, 0, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b', '\t',
    /* 0x10 */ 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0, 'A', 'S',
    /* 0x20 */ 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|', 'Z', 'X', 'C', 'V',
    /* 0x30 */ 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0,
    /* 0x40 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    /* 0x50 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

/* Read one key event. Returns 0 if no key, ASCII char for printable,
 * '\n' for Enter, '\b' for Backspace. */
static char keyboard_read(void) {
    /* Check if output buffer is full */
    if ((inb(0x64) & 0x01) == 0)
        return 0;

    unsigned char scancode = inb(0x60);

    /* Handle break codes (bit 7 set) */
    if (scancode & KEY_BREAK) {
        scancode &= ~KEY_BREAK;
        if (scancode == KEY_LSHIFT || scancode == KEY_RSHIFT)
            shift_pressed = 0;
        return 0;
    }

    /* Make codes */
    if (scancode == KEY_LSHIFT || scancode == KEY_RSHIFT) {
        shift_pressed = 1;
        return 0;
    }

    if (scancode == KEY_ENTER)
        return '\n';
    if (scancode == KEY_BACKSPACE)
        return '\b';

    if (scancode < sizeof(keymap_normal)) {
        char c = shift_pressed ? keymap_shifted[scancode] : keymap_normal[scancode];
        return c;
    }
    return 0;
}

/* ---------------------------------------------------------------------------
 * Main kernel
 * ------------------------------------------------------------------------- */

void kernel_main(void) {
    vga_clear_screen();
    vga_print("Hello, World!\n");
    vga_print("> ");

    input_len = 0;

    while (1) {
        char c = keyboard_read();
        if (c == 0)
            continue;   /* no key pressed */

        if (c == '\b') {
            if (input_len > 0) {
                input_len--;
                vga_putchar('\b');
            }
        } else if (c == '\n') {
            /* Newline: go to next line, print the buffered line again */
            vga_putchar('\n');
            input_buffer[input_len] = '\0';
            vga_print(input_buffer);
            vga_putchar('\n');
            vga_print("> ");
            input_len = 0;
        } else {
            /* Printable character */
            if (input_len < (int)sizeof(input_buffer) - 1) {
                input_buffer[input_len++] = c;
                vga_putchar(c);
            }
        }
    }
}

/* Entry point expected by the bootloader */
void _start(void) __attribute__((section(".text.startup"), noreturn));
void _start(void) {
    kernel_main();
    __builtin_unreachable();
}