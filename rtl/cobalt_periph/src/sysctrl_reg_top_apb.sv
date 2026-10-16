// APB wrapper for SYSCTRL register RTL.
`include "register_interface/typedef.svh"

module sysctrl_reg_top_apb #(
  parameter int AW = sysctrl_reg_pkg::BlockAw
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [31:0] PADDR,
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic [31:0] PRDATA,
  output logic        PREADY,
  output logic        PSLVERR,
  output logic [31:0] tohost_q,
  input  logic [31:0] chipid_d,
  input  logic [31:0] fromhost_d,
  input  logic        devmode_i
);

  `REG_BUS_TYPEDEF_ALL(sysctrl, logic [AW-1:0], logic [31:0], logic [3:0])

  sysctrl_req_t reg_req;
  sysctrl_rsp_t reg_rsp;
  sysctrl_reg_pkg::sysctrl_reg2hw_t reg2hw;
  sysctrl_reg_pkg::sysctrl_hw2reg_t hw2reg;

  always_comb begin
    reg_req.addr = PADDR[AW-1:0];
    reg_req.write = PWRITE;
    reg_req.wdata = PWDATA;
    reg_req.wstrb = PSTRB;
    reg_req.valid = PSEL & PENABLE;

    PRDATA = reg_rsp.rdata;
    PREADY = reg_rsp.ready;
    PSLVERR = reg_rsp.error;
  end

  assign tohost_q = reg2hw.tohost.q;
  assign hw2reg.chipid.d = chipid_d;
  assign hw2reg.chipid.de = 1'b1;
  assign hw2reg.fromhost.d = fromhost_d;
  assign hw2reg.fromhost.de = 1'b1;

  sysctrl_reg_top #(
    .reg_req_t(sysctrl_req_t),
    .reg_rsp_t(sysctrl_rsp_t),
    .AW(AW)
  ) i_regs (
    .clk_i,
    .rst_ni,
    .reg_req_i(reg_req),
    .reg_rsp_o(reg_rsp),
    .reg2hw(reg2hw),
    .hw2reg(hw2reg),
    .devmode_i
  );

endmodule
