/*
 * vim-bitwise demo file.
 *
 * HOVER (Neovim: on by default -- Vim: :let g:bitwise_hover = 1)
 *   Just put the cursor on any number below and wait a moment. The window
 *   appears next to it and goes away when you move off.
 *
 * OPERATOR
 *   <Leader>biw   on a literal        <Leader>bi(   inside the parentheses
 *   <Leader>biW   on a whole WORD     <Leader>b$    to end of line
 *   v3e<Leader>b  on a visual selection
 *
 * COMMAND
 *   :Bitwise 1 << 12 | 3
 *   :Bitwise           (uses the word under the cursor)
 *   :BitwiseHover      (hover immediately, no waiting)
 */

#include <stdint.h>

/* --- hexadecimal ------------------------------------------------------- */

#define UART_BASE        0x40011000
#define GPIO_ODR         0x8040201
#define MAGIC            0xDEADBEEF
#define BYTE_MASK        0xFF
#define NIBBLE           0xf

/* --- binary (C23 / GCC extension) -------------------------------------- */

#define ALTERNATING      0b10101010
#define HIGH_NIBBLE      0b11110000
#define SINGLE_BIT       0b1

/* --- octal -------------------------------------------------------------- */

#define FILE_MODE        0755
#define PERMISSIONS      0644

/* --- decimal ------------------------------------------------------------ */

#define BAUD_RATE        115200
#define TIMEOUT_MS       250
#define ANSWER           42

/* --- size suffixes: the suffix is stripped before bitwise sees it ------- */

#define ALL_ONES         0xFFFFFFFFUL
#define BIG              100ULL
#define ONE              1U
#define LONG_MASK        0x0F0F0F0FL

/* --- digit separators are stripped too ---------------------------------- */

#define WITH_SEPARATORS  1_000_000
#define RUST_STYLE       0xFF_u8
#define GROUPED_BITS     0b1010_1010

/* --- try the operator on these expressions ------------------------------
 *
 * Put the cursor inside the parentheses and press <Leader>bi(
 */

#define CTRL_ENABLE      (1 << 12)
#define CTRL_MODE        (3 << 4 | 1 << 2)
#define CTRL_CLEAR       (0xFFFF & ~0x00F0)

/* --- deliberately ignored by the hover ----------------------------------
 *
 * Nothing should pop up on any of these: digits inside an identifier, a
 * hex-looking word with no 0x prefix, or either half of a float.
 *
 * OCTAL_0O below is a different case: the plugin recognises the 0o prefix,
 * but bitwise itself does not parse it, so the hover stays silent. C octal
 * (0755 above) works fine.
 */

#define OCTAL_0O         0o17

static int   foo123;
static int   deadbeef;
static float ratio      = 1.5;
static float scaled     = 3.14159;

/* --- a realistic bit of register work ----------------------------------- */

struct uart_regs {
	volatile uint32_t sr;
	volatile uint32_t dr;
	volatile uint32_t brr;
	volatile uint32_t cr1;
};

#define USART_CR1_UE     (1 << 13)
#define USART_CR1_TE     (1 << 3)
#define USART_CR1_RE     (1 << 2)
#define USART_SR_TXE     (1 << 7)

static void uart_init(struct uart_regs *uart)
{
	uart->brr = 0x0683;
	uart->cr1 = USART_CR1_UE | USART_CR1_TE | USART_CR1_RE;
}

static void uart_putc(struct uart_regs *uart, char c)
{
	while (!(uart->sr & USART_SR_TXE))
		;
	uart->dr = c & 0xFF;
}
