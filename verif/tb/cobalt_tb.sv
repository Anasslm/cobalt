
module cobalt_tb;


  import cobalt_pkg::*;

  // Parameters

  localparam logic [31:0] TOHOST_MAGIC = 32'h434F4241; // "COBA"

  localparam logic [7:0] TOHOST_CMD_PUTCHAR = 8'h01;
  localparam logic [7:0] TOHOST_CMD_EXIT    = 8'hFF;

  // UART configuration: matching the firmware ( params.h ).

  parameter int unsigned  UartBaudRate      = 115200;
  parameter int unsigned  UartParityEna     = 0;
  parameter int unsigned  UartBurstBytes    = 256;
  parameter int unsigned  UartWaitCycles    = 60;

  // UART VIP tasks and monitor
  `include "uart_vip.svh"



  task wait_for_reset;
    @(posedge rst_ni);
    @(posedge clk_i);
  endtask


  //Ports
  reg clk_i;
  reg rst_ni;

  logic uart_tx;
  logic uart_rx;

task automatic uart_check_message;
    byte_bt received;
    string expected = "KA\r\n";
    int errors = 0;

    for (int i = 0; i < expected.len(); i++) begin
        uart_read_byte(received);

        if (received !== expected[i]) begin
            $error(
                "[UART TEST] Byte %0d: expected 0x%02h, received 0x%02h",
                i, expected[i], received
            );
            errors++;
        end
    end

    if (errors == 0)
        $display("[UART TEST] PASS: message received correctly");
    else
        $error("[UART TEST] FAIL: %0d mismatched bytes", errors);
endtask


  cobalt_soc  i_cobalt_soc (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tx_o(uart_tx),
    .rx_i(uart_rx)
  );

initial uart_rx = 1'b1; // UART idle level

initial begin
    $display("COBALT TB");
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
end


byte_bt received;

initial begin
    rst_ni = 1'b0;
    $readmemh("verif/tb/sram_program.mem", i_cobalt_soc.i_tc_sram.sram);
    repeat (10) @(posedge clk_i);
    rst_ni = 1'b1;
    repeat (1000) @(posedge clk_i);

  //  uart_check_message();

    

    uart_read_byte(received);

    uart_write_byte(received); // Send newline 

    

    // timeout
    repeat (10000000) @(posedge clk_i);
    $display("*** TIMEOUT: no tohost write seen ***");
    $finish;

end

initial begin    
    $dumpfile("cobalt.vcd");
    $dumpvars(0, cobalt_tb);
end


  // --- tohost monitoring ---
  localparam int unsigned TOHOST_WORD = 512;   // 0x200
  localparam int unsigned FROMHOST_WORD = 513; // 0x201 (optional)

  /*
63                  32 31       24 23       16 15        0
+---------------------+-----------+-----------+-----------+
|        MAGIC        |    CMD    | RESERVED  |  PAYLOAD  |
+---------------------+-----------+-----------+-----------+
     0x434F4241

  */


always @(posedge clk_i) begin
  if (rst_ni &&
      i_cobalt_soc.i_tc_sram.req_i[0] &&
      i_cobalt_soc.i_tc_sram.we_i[0] &&
      i_cobalt_soc.i_tc_sram.addr_i[0] == TOHOST_WORD) begin

    logic [63:0] val;
    val = i_cobalt_soc.i_tc_sram.wdata_i[0];

    // Check TOHOST magic
    if (val[63:32] != TOHOST_MAGIC) begin
      $display("[%0t] WARNING: invalid TOHOST message: 0x%016h",
               $time, val);
    end
    else begin

      case (val[31:24])

        // --------------------------------------------------
        // PUTCHAR
        // --------------------------------------------------
        TOHOST_CMD_PUTCHAR: begin
          $write("%c", val[7:0]);

          if (val[7:0] == 8'h0A)
  //          $display("[TOHOST] Line completed at %0t", $time);
            $fflush();
        end


        // --------------------------------------------------
        // EXIT
        // --------------------------------------------------
        TOHOST_CMD_EXIT: begin
          $display("");
          $display("=========================================");
          $display("COBALT TEST FINISHED");
          $display("EXIT CODE = %0d (0x%0h)",
                   val[15:0], val[15:0]);
          $display("=========================================");
        
          if (val[15:0] == 16'h0000) begin
            $display("██████╗  █████╗ ███████╗███████╗");
            $display("██╔══██╗██╔══██╗██╔════╝██╔════╝");
            $display("██████╔╝███████║███████╗███████╗");
            $display("██╔═══╝ ██╔══██║╚════██║╚════██║");
            $display("██║     ██║  ██║███████║███████║");
            $display("╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝");
            $display("RESULT = PASS");
            $finish;
          end else begin
            $display("███████╗ █████╗ ██╗██╗     ");
            $display("██╔════╝██╔══██╗██║██║     ");
            $display("█████╗  ███████║██║██║     ");
            $display("██╔══╝  ██╔══██║██║██║     ");
            $display("██║     ██║  ██║██║███████╗"); 
            $display("╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝");
            $display("RESULT = FAIL");
            $finish;
          end
        end


        // --------------------------------------------------
        // UNKNOWN COMMAND
        // --------------------------------------------------
        default: begin
          $display("[%0t] WARNING: unknown TOHOST command = 0x%02h",
                   $time, val[31:24]);
        end

      endcase
    end
  end
end

endmodule