#include "cobalt.h"
#include <stdarg.h>
#include <stdint.h>

static void print_char(char c)
{
    cobalt_putchar(c);
}

static void print_string(const char *s)
{
    while (*s)
        print_char(*s++);
}

static void print_unsigned(uint64_t value, unsigned base)
{
    static const char digits[] = "0123456789abcdef";
    char buffer[16];
    int i = 0;

    if (value == 0) {
        print_char('0');
        return;
    }

    while (value != 0) {
        buffer[i++] = digits[value % base];
        value /= base;
    }

    while (i > 0)
        print_char(buffer[--i]);
}

static void print_signed(int64_t value)
{
    if (value < 0) {
        print_char('-');
        print_unsigned((uint64_t)(-value), 10);
    } else {
        print_unsigned((uint64_t)value, 10);
    }
}

void cobalt_printf(const char *format, ...)
{
    va_list args;

    va_start(args, format);

    while (*format) {

        if (*format != '%') {
            print_char(*format++);
            continue;
        }

        format++;

        switch (*format) {

        case '%':
            print_char('%');
            break;

        case 'c':
            print_char((char)va_arg(args, int));
            break;

        case 's':
            print_string(va_arg(args, const char *));
            break;

        case 'd':
            print_signed(va_arg(args, int));
            break;

        case 'u':
            print_unsigned(va_arg(args, unsigned int), 10);
            break;

        case 'x':
            print_unsigned(va_arg(args, unsigned int), 16);
            break;

        default:
            print_char('%');
            print_char(*format);
            break;
        }

        format++;
    }

    va_end(args);
}