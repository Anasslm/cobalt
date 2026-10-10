// Generic SoC smoke test.
// Included inside cobalt_tb when no test-specific SVH exists.
//
// The base testbench handles:
//   - Clock and reset
//   - SRAM initialization
//   - TOHOST PASS/FAIL
//   - Global simulation timeout

initial begin : soc_smoke_test
    $display("[SMOKE TEST] Generic SoC smoke test selected");

    // Wait until reset has been released.
    wait (rst_ni === 1'b1);

    $display("[SMOKE TEST] Reset released");
end