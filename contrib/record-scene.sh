#!/bin/bash
# Set up the recording scene: a terminal on the virtual display running nvim.
S="$(cd "$(dirname "$0")" && pwd)"
export DISPLAY=:99
pkill -f 'xfce4.termin.*bitwise.demo' 2>/dev/null
sleep 1
rm -f "$S/demo.sock"
mkdir -p "$S/scene"

cat > "$S/scene/uart.c" <<'CEOF'
/* STM32 USART configuration */

#define UART_BASE        0x40011000
#define GPIO_ODR         0x8040201
#define MAGIC            0xDEADBEEF
#define ALTERNATING      0b10101010
#define BAUD_RATE        115200

static void uart_init(struct uart_regs *uart)
{
	uart->brr = 0x0683;
	uart->cr1 = (3 << 4 | 1 << 2);
}
CEOF

setsid xfce4-terminal --disable-server --hide-menubar --hide-toolbar --hide-scrollbar \
  --hide-borders --font="DejaVu Sans Mono 14" --geometry=84x24 --title=bitwise-demo \
  --working-directory="$S/scene" \
  --command "nvim --listen $S/demo.sock uart.c" >/dev/null 2>&1 < /dev/null &

for i in $(seq 1 60); do [ -S "$S/demo.sock" ] && break; sleep 0.5; done
sleep 3
xdotool mousemove 1099 679
echo "socket: $([ -S "$S/demo.sock" ] && echo ok || echo MISSING)"
xdotool getwindowgeometry "$(xdotool search --name bitwise-demo | head -1)" | tail -1
