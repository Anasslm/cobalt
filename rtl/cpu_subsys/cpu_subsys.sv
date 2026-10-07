


module cpu_subsys #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cobalt_cva6_config_pkg::cva6_cfg),
    parameter int unsigned AxiAddrWidth = cobalt_axi::AddrWidth,
    parameter int unsigned AxiDataWidth = cobalt_axi::DataWidth,
    parameter int unsigned AxiIdWidth   = cobalt_axi::IdWidth,
    parameter type axi_ar_chan_t = cobalt_axi::ar_chan_t,
    parameter type axi_aw_chan_t = cobalt_axi::aw_chan_t,
    parameter type axi_w_chan_t  = cobalt_axi::w_chan_t,
    parameter type noc_req_t = cobalt_axi::req_t,
    parameter type noc_resp_t = cobalt_axi::resp_t
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic [CVA6Cfg.VLEN-1:0]      boot_addr_i,
    input  logic [CVA6Cfg.XLEN-1:0]      hart_id_i,
    input  logic [1:0]                   irq_i,
    input  logic                         time_irq_i,
    input  logic                         debug_req_i,

    output noc_req_t                      axi_req,
    input  noc_resp_t                     axi_rsp
);




  cva6 #(
    .CVA6Cfg ( CVA6Cfg ),
    .axi_ar_chan_t (axi_ar_chan_t),
    .axi_aw_chan_t (axi_aw_chan_t),
    .axi_w_chan_t (axi_w_chan_t),
    .noc_req_t (noc_req_t),
    .noc_resp_t (noc_resp_t)
   ) i_cva6 (
    .clk_i                ( clk_i                        ),
    .rst_ni               ( rst_ni                       ),
    .boot_addr_i          ( boot_addr_i                  ), //Driving the boot_addr value from the core control agent
    .hart_id_i            ( hart_id_i                    ),
    .irq_i                ( irq_i                        ),
    .ipi_i                ( 1'b0                         ),
    .time_irq_i           ( time_irq_i                   ),
    .debug_req_i          ( debug_req_i                  ),
    .rvfi_probes_o        (                              ), // Probes to build RVFI, can be left open when not used - RVFI
    .cvxif_req_o          (                              ),
    .cvxif_resp_i         ( 0                            ),
    .noc_req_o            ( axi_req                      ),
    .noc_resp_i           ( axi_rsp                      )
  );

  


endmodule