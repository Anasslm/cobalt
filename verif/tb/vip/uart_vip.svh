  ////////////
  //  UART  //
  ////////////

  localparam time UartBaudPeriod = 1000ns*1000*1000/UartBaudRate;

  localparam byte_bt UartDebugCmdRead  = 'h11;
  localparam byte_bt UartDebugCmdWrite = 'h12;
  localparam byte_bt UartDebugCmdExec  = 'h13;
  localparam byte_bt UartDebugAck      = 'h06;
  localparam byte_bt UartDebugEot      = 'h04;
  localparam byte_bt UartDebugEoc      = 'h14;

  byte_bt uart_boot_byte;
  logic   uart_boot_ena;
  logic   uart_boot_eoc;
  logic   uart_reading_byte;

  initial begin
    uart_rx           = 1;
    uart_boot_eoc     = 0;
    uart_boot_ena     = 0;
    uart_reading_byte = 0;
  end

  task automatic uart_read_byte(output byte_bt bite);
    // Start bit
    @(negedge uart_tx);
    uart_reading_byte = 1;
    #(UartBaudPeriod/2);
    // 8-bit byte
    for (int i = 0; i < 8; i++) begin
      #UartBaudPeriod bite[i] = uart_tx;
    end
    // Parity bit
    if(UartParityEna) begin
      bit parity;
      #UartBaudPeriod parity = uart_tx;
      if(parity ^ (^bite))
        $error("[UART] - Parity error detected!");
    end
    // Stop bit
    #UartBaudPeriod;
    uart_reading_byte=0;
  endtask

  task automatic uart_write_byte(input byte_bt bite);
    // Start bit
    uart_rx = 1'b0;
    // 8-bit byte
    for (int i = 0; i < 8; i++)
      #UartBaudPeriod uart_rx = bite[i];
    // Parity bit
    if (UartParityEna)
      #UartBaudPeriod uart_rx = (^bite);
    // Stop bit
    #UartBaudPeriod uart_rx = 1'b1;
    #UartBaudPeriod;
  endtask
  
  /* Anass : Commented for now as i have some issue with DPI and the elfloader.cpp file. I will re-enable it once i fix the issue.

  task automatic uart_boot_scoop(output byte_bt bite);
    // Assert our intention to scoop the next received byte
    uart_boot_ena = 1;
    // Wait until read task notifies us a scooped byte is available
    @(negedge uart_boot_ena);
    // Grab scooped byte
    bite = uart_boot_byte;
  endtask

  task automatic uart_boot_scoop_expect(input string name, input byte_bt exp);
    byte_bt bite;
    uart_boot_scoop(bite);
    if (bite != exp)
      $fatal(1, "[UART] Expected %s (%0x) after read command, received %0x", name, exp, bite);
  endtask

  // Continually read characters and print lines
  // TODO: we should be able to support CR properly, but buffers are hard to deal with...
  initial begin
    static byte_bt uart_read_buf [$];
    byte_bt bite;
    string line;
    wait_for_reset();
    forever begin
      uart_read_byte(bite);
      if (uart_boot_ena) begin
        uart_boot_byte  = bite;
        uart_boot_ena = 0;
      end else if (bite == "\n") begin
        if (uart_read_buf.size() > 0) begin
          line = {>>8{uart_read_buf}};
          $display("[UART] %s", line);
          uart_read_buf.delete();
        end else begin
          $display("[UART]");
        end
      end else if (bite == UartDebugEoc) begin
        uart_boot_eoc = 1;
      end else begin
        uart_read_buf.push_back(bite);
      end
    end
  end

  // A length of zero indcates a write (write lengths are inferred from their queue)
  task automatic uart_debug_rw(doub_bt addr, doub_bt len_or_w, ref byte_bt data [$]);
    byte_bt bite;
    doub_bt len = len_or_w ? len_or_w : data.size();
    // Send command, address, and length
    uart_write_byte(len_or_w ? UartDebugCmdRead : UartDebugCmdWrite);
    for (int i = 0; i < 8; ++i)
      uart_write_byte(addr[8*i +: 8]);
        for (int i = 0; i < 8; ++i)
      uart_write_byte(len[8*i +: 8]);
    // Receive and check ACK
    uart_boot_scoop_expect("ACK", UartDebugAck);
    // Send or receive requested data
    for (int i = 0; i < len; ++i) begin
      if (len_or_w) begin
        uart_boot_scoop(bite);
        data.push_back(bite);
      end else begin
        uart_write_byte(data[i]);
      end
    end
    // Receive and check EOT
    uart_boot_scoop_expect("EOT", UartDebugEot);
  endtask


  // Load a binary
  task automatic uart_debug_elf_preload(input string binary, output doub_bt entry);
    longint sec_addr, sec_len;
    $display("[UART] Preloading ELF binary: %s", binary);
    if (read_elf(binary))
      $fatal(1, "[UART] Failed to load ELF!");
    while (get_section(sec_addr, sec_len)) begin
      byte bf[] = new [sec_len];
      $display("[UART] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[UART] Failed to read ELF section!");
      // Write section in blocks
      for (longint i = 0; i <= sec_len ; i += UartBurstBytes) begin
        byte_bt bytes [$];
        if (i != 0)
          $display("[UART] - %0d/%0d bytes (%0d%%)", i, sec_len, i*100/(sec_len>1 ? sec_len-1 : 1));
        for (int b = 0; b < UartBurstBytes; b++) begin
          if (i+b >= sec_len) break;
          bytes.push_back(bf [i+b]);
        end
        uart_debug_rw(sec_addr + i, 0, bytes);
      end
    end
    void'(get_entry(entry));
    $display("[UART] Preload complete");
  endtask
  

  task automatic uart_debug_elf_run_and_wait(input string binary, output word_bt exit_code);
    byte_bt bite;
    doub_bt entry;
    // Wait some time for boot ROM to settle (No way to query this using only UART)
    $display("[UART] Waiting for debug loop to start");
    #(UartWaitCycles*UartBaudPeriod);
    // We send an ACK challenge to the debug server and wait for an ACK response
    $display("[UART] Sending ACK challenge");
    uart_write_byte(UartDebugAck);
    uart_boot_scoop_expect("ACK", UartDebugAck);
    // Preload
    uart_debug_elf_preload(binary, entry);
    $display("[UART] Sending EXEC command for address %0x", entry);
    // Send exec command and receive ACK
    uart_write_byte(UartDebugCmdExec);
    for (int i = 0; i < 8; ++i)
      uart_write_byte(entry[8*i +: 8]);
    uart_boot_scoop_expect("ACK", UartDebugAck);
    // Wait for EOC and read return code
    wait (uart_boot_eoc == 1);
    $display("[UART] Received EOC signal");
    uart_boot_eoc = 0;
    for (int i = 0; i < 4; ++i)
      uart_boot_scoop(exit_code[8*i +: 8]);
    // Report exit code
    if (exit_code) $error("[UART] FAILED: return code %0d", exit_code);
    else $display("[UART] SUCCESS");
  endtask

  */