// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// ----------------------------
// AXI to SRAM Adapter
// ----------------------------
// Author: Florian Zaruba (zarubaf@iis.ee.ethz.ch)
//
// Description: Manages AXI transactions
//              Supports all burst accesses but only on aligned addresses and with full data width.
//              Assertions should guide you if there is something unsupported happening.
//
module cobalt_axi2mem #(
    parameter int unsigned AXI_ID_WIDTH      = 10,
    parameter int unsigned AXI_ADDR_WIDTH    = 64,
    parameter int unsigned AXI_DATA_WIDTH    = 64,
    parameter int unsigned AXI_USER_WIDTH    = 10,
    parameter type                    req_t  = logic,
    parameter type                    resp_t = logic

)(
    input logic                         clk_i,    // Clock
    input logic                         rst_ni,  // Asynchronous reset active low
    input  req_t                        axi_req_i,
    output resp_t                       axi_resp_o,
    output logic                        req_o,
    output logic                        we_o,
    output logic [AXI_ADDR_WIDTH-1:0]   addr_o,
    output logic [AXI_DATA_WIDTH/8-1:0] be_o,
    output logic [AXI_USER_WIDTH-1:0]   user_o,
    output logic [AXI_DATA_WIDTH-1:0]   data_o,
    input  logic [AXI_USER_WIDTH-1:0]   user_i,
    input  logic [AXI_DATA_WIDTH-1:0]   data_i
);

    // AXI has the following rules governing the use of bursts:
    // - for wrapping bursts, the burst length must be 2, 4, 8, or 16
    // - a burst must not cross a 4KB address boundary
    // - early termination of bursts is not supported.
    typedef enum logic [1:0] { FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10} axi_burst_t;

    localparam LOG_NR_BYTES = $clog2(AXI_DATA_WIDTH/8);

    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0]   id;
        logic [AXI_ADDR_WIDTH-1:0] addr;
        logic [7:0]                len;
        logic [2:0]                size;
        axi_burst_t                burst;
    } ax_req_t;

    // Registers
    enum logic [2:0] { IDLE, READ, WRITE, SEND_B, WAIT_WVALID }  state_d, state_q;
    ax_req_t                   ax_req_d, ax_req_q;
    logic [AXI_ADDR_WIDTH-1:0] req_addr_d, req_addr_q;
    logic [7:0]                cnt_d, cnt_q;

    function automatic logic [AXI_ADDR_WIDTH-1:0] get_wrap_boundary (input logic [AXI_ADDR_WIDTH-1:0] unaligned_address, input logic [7:0] len);
        logic [AXI_ADDR_WIDTH-1:0] warp_address = '0;
        //  for wrapping transfers ax_len can only be of size 1, 3, 7 or 15
        if (len == 4'b1)
            warp_address[AXI_ADDR_WIDTH-1:1+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-1:1+LOG_NR_BYTES];
        else if (len == 4'b11)
            warp_address[AXI_ADDR_WIDTH-1:2+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-1:2+LOG_NR_BYTES];
        else if (len == 4'b111)
            warp_address[AXI_ADDR_WIDTH-1:3+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-3:2+LOG_NR_BYTES];
        else if (len == 4'b1111)
            warp_address[AXI_ADDR_WIDTH-1:4+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-3:4+LOG_NR_BYTES];

        return warp_address;
    endfunction

    logic [AXI_ADDR_WIDTH-1:0] aligned_address;
    logic [AXI_ADDR_WIDTH-1:0] wrap_boundary;
    logic [AXI_ADDR_WIDTH-1:0] upper_wrap_boundary;
    logic [AXI_ADDR_WIDTH-1:0] cons_addr;

    always_comb begin
        // address generation
        aligned_address = {ax_req_q.addr[AXI_ADDR_WIDTH-1:LOG_NR_BYTES], {{LOG_NR_BYTES}{1'b0}}};
        wrap_boundary = get_wrap_boundary(ax_req_q.addr, ax_req_q.len);
        // this will overflow
        upper_wrap_boundary = wrap_boundary + ((ax_req_q.len + 1) << LOG_NR_BYTES);
        // calculate consecutive address
        cons_addr = aligned_address + (cnt_q << LOG_NR_BYTES);

        // Transaction attributes
        // default assignments
        state_d    = state_q;
        ax_req_d   = ax_req_q;
        req_addr_d = req_addr_q;
        cnt_d      = cnt_q;
        // Memory default assignments
        data_o = axi_req_i.w.data;
        user_o = axi_req_i.w.user;
        be_o   = axi_req_i.w.strb;
        we_o   = 1'b0;
        req_o  = 1'b0;
        addr_o = '0;
        // AXI assignments
        // request
        axi_resp_o.aw_ready = 1'b0;
        axi_resp_o.ar_ready = 1'b0;
        // read response channel
        axi_resp_o.r_valid  = 1'b0;
        axi_resp_o.r.data   = data_i;
        axi_resp_o.r.resp   = '0;
        axi_resp_o.r.last   = '0;
        axi_resp_o.r.id     = ax_req_q.id;
        axi_resp_o.r.user   = user_i;
        // slave write data channel
        axi_resp_o.w_ready  = 1'b0;
        // write response channel
        axi_resp_o.b_valid  = 1'b0;
        axi_resp_o.b.resp   = 1'b0;
        axi_resp_o.b.id     = 1'b0;
        axi_resp_o.b.user   = 1'b0;

        case (state_q)

            IDLE: begin
                // Wait for a read or write
                // ------------
                // Read
                // ------------
                if (axi_req_i.ar_valid) begin
                    axi_resp_o.ar_ready = 1'b1;
                    // sample ax
                    ax_req_d       = {axi_req_i.ar.id, axi_req_i.ar.addr, axi_req_i.ar.len, axi_req_i.ar.size, axi_req_i.ar.burst};
                    state_d        = READ;
                    //  we can request the first address, this saves us time
                    req_o          = 1'b1;
                    addr_o         = axi_req_i.ar.addr;
                    // save the address
                    req_addr_d     = axi_req_i.ar.addr;
                    // save the ar_len
                    cnt_d          = 1;
                // ------------
                // Write
                // ------------
                end else if (axi_req_i.aw_valid) begin
                    axi_resp_o.aw_ready = 1'b1;
                    axi_resp_o.w_ready  = 1'b1;
                    addr_o         = axi_req_i.aw.addr;
                    // sample ax
                    ax_req_d       = {axi_req_i.aw.id, axi_req_i.aw.addr, axi_req_i.aw.len, axi_req_i.aw.size, axi_req_i.aw.burst};
                    // we've got our first w_valid so start the write process
                    if (axi_req_i.w_valid) begin
                        req_o          = 1'b1;
                        we_o           = 1'b1;
                        state_d        = (axi_req_i.w.last) ? SEND_B : WRITE;
                        cnt_d          = 1;
                    // we still have to wait for the first w_valid to arrive
                    end else
                        state_d = WAIT_WVALID;
                end
            end

            // ~> we are still missing a w_valid
            WAIT_WVALID: begin
                axi_resp_o.w_ready = 1'b1;
                addr_o = ax_req_q.addr;
                // we can now make our first request
                if (axi_req_i.w_valid) begin
                    req_o          = 1'b1;
                    we_o           = 1'b1;
                    state_d        = (axi_req_i.w.last) ? SEND_B : WRITE;
                    cnt_d          = 1;
                end
            end

            READ: begin
                // keep request to memory high
                req_o  = 1'b1;
                addr_o = req_addr_q;
                // send the response
                axi_resp_o.r_valid = 1'b1;
                axi_resp_o.r.data  = data_i;
                axi_resp_o.r.user  = user_i;
                axi_resp_o.r.id    = ax_req_q.id;
                axi_resp_o.r.last  = (cnt_q == ax_req_q.len + 1);

                // check that the master is ready, the slave must not wait on this
                if (axi_req_i.r_ready) begin
                    // ----------------------------
                    // Next address generation
                    // ----------------------------
                    // handle the correct burst type
                    case (ax_req_q.burst)
                        FIXED, INCR: addr_o = cons_addr;
                        WRAP:  begin
                            // check if the address reached warp boundary
                            if (cons_addr == upper_wrap_boundary) begin
                                addr_o = wrap_boundary;
                            // address warped beyond boundary
                            end else if (cons_addr > upper_wrap_boundary) begin
                                addr_o = ax_req_q.addr + ((cnt_q - ax_req_q.len) << LOG_NR_BYTES);
                            // we are still in the incremental regime
                            end else begin
                                addr_o = cons_addr;
                            end
                        end
                    endcase
                    // we need to change the address here for the upcoming request
                    // we sent the last byte -> go back to idle
                    if (axi_resp_o.r.last) begin
                        state_d = IDLE;
                        // we already got everything
                        req_o = 1'b0;
                    end
                    // save the request address for the next cycle
                    req_addr_d = addr_o;
                    // we can decrease the counter as the master has consumed the read data
                    cnt_d = cnt_q + 1;
                    // TODO: configure correct byte-lane
                end
            end
            // ~> we already wrote the first word here
            WRITE: begin

                axi_resp_o.w_ready = 1'b1;

                // consume a word here
                if (axi_req_i.w_valid) begin
                    req_o         = 1'b1;
                    we_o          = 1'b1;
                    // ----------------------------
                    // Next address generation
                    // ----------------------------
                    // handle the correct burst type
                    case (ax_req_q.burst)

                        FIXED, INCR: addr_o = cons_addr;
                        WRAP:  begin
                            // check if the address reached warp boundary
                            if (cons_addr == upper_wrap_boundary) begin
                                addr_o = wrap_boundary;
                            // address warped beyond boundary
                            end else if (cons_addr > upper_wrap_boundary) begin
                                addr_o = ax_req_q.addr + ((cnt_q - ax_req_q.len) << LOG_NR_BYTES);
                            // we are still in the incremental regime
                            end else begin
                                addr_o = cons_addr;
                            end
                        end
                    endcase
                    // save the request address for the next cycle
                    req_addr_d = addr_o;
                    // we can decrease the counter as the master has consumed the read data
                    cnt_d = cnt_q + 1;

                    if (axi_req_i.w.last)
                        state_d = SEND_B;
                end
            end
            // ~> send a write acknowledge back
            SEND_B: begin
                axi_resp_o.b_valid = 1'b1;
                axi_resp_o.b.id    = ax_req_q.id;
                if (axi_req_i.b_ready)
                    state_d = IDLE;
            end

        endcase
    end

    `ifndef SYNTHESIS
    `ifndef VERILATOR
    // assert that only full data lane transfers allowed
    // assert property (
    //   @(posedge clk_i) slave.aw_valid |-> (slave.aw_size == LOG_NR_BYTES)) else $fatal ("Only full data lane transfers allowed");
    //   assert property (
    //   @(posedge clk_i) slave.ar_valid |-> (slave.ar_size == LOG_NR_BYTES)) else $fatal ("Only full data lane transfers allowed");
    // assert property (
    //   @(posedge clk_i) slave.aw_valid |-> (slave.ar_addr[LOG_NR_BYTES-1:0] == '0)) else $fatal ("Unaligned accesses are not allowed at the moment");
    // assert property (
    //   @(posedge clk_i) slave.ar_valid |-> (slave.aw_addr[LOG_NR_BYTES-1:0] == '0)) else $fatal ("Unaligned accesses are not allowed at the moment");
    `endif
    `endif
    // --------------
    // Registers
    // --------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q    <= IDLE;
            ax_req_q  <= '0;
            req_addr_q <= '0;
            cnt_q      <= '0;
        end else begin
            state_q    <= state_d;
            ax_req_q   <= ax_req_d;
            req_addr_q <= req_addr_d;
            cnt_q      <= cnt_d;
        end
    end
endmodule


