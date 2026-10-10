// UART loopback smoke test.
// This file is included inside cobalt_tb.

byte_bt received;

task automatic uart_check_message;
    byte_bt rx_byte;
    string expected = "KA\r\n";
    int errors = 0;

    for (int i = 0; i < expected.len(); i++) begin
        uart_read_byte(rx_byte);

        if (rx_byte !== expected[i]) begin
            $error(
                "[UART TEST] Byte %0d: expected 0x%02h, received 0x%02h",
                i, expected[i], rx_byte
            );
            errors++;
        end
    end

    if (errors == 0)
        $display("[UART TEST] PASS: message received correctly");
    else
        $error("[UART TEST] FAIL: %0d mismatched bytes", errors);
endtask

initial begin : uart_loopback_test
    // Wait until reset is released.
    wait_for_reset();

    // Temporary delay retained from the original testbench.
    repeat (1000) @(posedge clk_i);

    // Receive one byte from the SoC TX and echo it to the SoC RX.
    uart_read_byte(received);
    uart_write_byte(received);


end