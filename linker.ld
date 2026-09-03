OUTPUT_FORMAT(binary)
ENTRY(_start)
SECTIONS
{
    . = 0x8000;
    .text : { *(.text.startup) *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }
}