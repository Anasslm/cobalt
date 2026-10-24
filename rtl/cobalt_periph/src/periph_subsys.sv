module periph_subsys #(
    parameter type axi_req_t  = logic,
    parameter type axi_resp_t = logic,
    parameter AxiIdWidth = 5
)
(
    input clk_i,
    input rtc_clk_i,
    input rst_ni,

    // AXI Slave Interface
    input  axi_req_t  axi_req_i,
    output axi_resp_t axi_resp_o,

    // UART
    input  logic  rx_i,
    output logic  tx_o,

    // IRQs
    output logic timer_irq_o
);

`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

localparam int unsigned NoAPBMstPorts = cobalt_pkg::NB_APB_PERIPHERALS;

typedef logic [31:0]  paddr_t;
typedef logic [31:0]  pdata_t;
typedef logic [3:0]   pstrb_t;

// define types for slaves and masters of the xbar
`APB_TYPEDEF_ALL(apb, paddr_t, pdata_t, pstrb_t)
apb_req_t  apb_req;
apb_resp_t apb_rsp;

apb_req_t [NoAPBMstPorts-1:0]   apb_demux_req;
apb_resp_t [NoAPBMstPorts-1:0]  apb_demux_rsp;

axi_to_apb # (
    .NoRules(0),
    .AxiAddrWidth(64),
    .AxiDataWidth(64),
    .AxiIdWidth(AxiIdWidth),
    .AxiUserWidth(64),
    .ApbAddrWidth(32),
    .ApbDataWidth(32),
    .axi_req_t (axi_req_t),
    .axi_resp_t(axi_resp_t),
    .apb_req_t(apb_req_t),
    .apb_resp_t(apb_resp_t)
  )
  i_axi_to_apb (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .axi_req_i(axi_req_i),
    .axi_resp_o(axi_resp_o),
    .apb_req_o (apb_req),
    .apb_resp_i(apb_rsp),
    .addr_map_i(0)
  );



  typedef struct packed {
    int unsigned idx;
    paddr_t      start_addr;
    paddr_t      end_addr;
  } rule_t;


  rule_t [NoAPBMstPorts-1:0] apb_addr_map;
  logic [$clog2(NoAPBMstPorts)-1:0] select;


  assign apb_addr_map = '{
  '{ idx: cobalt_pkg::CLINT,    start_addr: cobalt_pkg::CLINTBase,    end_addr: cobalt_pkg::CLINTBase + cobalt_pkg::CLINTLength       },
  '{ idx: cobalt_pkg::SYSCTRL,  start_addr: cobalt_pkg::SYSCTRLBase,  end_addr: cobalt_pkg::SYSCTRLBase + cobalt_pkg::SYSCTRLLength   },
  '{ idx: cobalt_pkg::PLIC,     start_addr: cobalt_pkg::PLICBase,     end_addr: cobalt_pkg::PLICBase + cobalt_pkg::PLICLength         },
  '{ idx: cobalt_pkg::UART,     start_addr: cobalt_pkg::UARTBase,     end_addr: cobalt_pkg::UARTBase + cobalt_pkg::UARTLength         },
  '{ idx: cobalt_pkg::Timer,    start_addr: cobalt_pkg::TimerBase,    end_addr: cobalt_pkg::TimerBase + cobalt_pkg::TimerLength       },
  '{ idx: cobalt_pkg::SPI,      start_addr: cobalt_pkg::SPIBase,      end_addr: cobalt_pkg::SPIBase + cobalt_pkg::SPILength           },
  '{ idx: cobalt_pkg::Ethernet, start_addr: cobalt_pkg::EthernetBase, end_addr: cobalt_pkg::EthernetBase + cobalt_pkg::EthernetLength },
  '{ idx: cobalt_pkg::GPIO,     start_addr: cobalt_pkg::GPIOBase,     end_addr: cobalt_pkg::GPIOBase + cobalt_pkg::GPIOLength         }
 };

    addr_decode #(
    .NoIndices ( NoAPBMstPorts ),
    .NoRules   ( NoAPBMstPorts ),
    .addr_t    ( paddr_t ),
    .rule_t    ( rule_t     )
  ) i_addr_decode(
    .addr_i           ( apb_req.paddr       ),
    .addr_map_i       ( apb_addr_map        ),
    .idx_o            ( select              ),
    .dec_valid_o      (                     ),
    .dec_error_o      (                     ),
    .en_default_idx_i ( 1'b1                ),
    .default_idx_i    ( '0                  )
  );

apb_demux # (
    .NoMstPorts(NoAPBMstPorts),
    .SelectWidth($clog2(NoAPBMstPorts)),
    .req_t(apb_req_t),
    .resp_t(apb_resp_t)
  )
  apb_demux_inst (
    .slv_req_i(apb_req),
    .slv_resp_o(apb_rsp),
    .mst_req_o (apb_demux_req),
    .mst_resp_i(apb_demux_rsp),
    .select_i(select)
  );


  clint #(
    .apb_req_t(apb_req_t ),
    .apb_rsp_t(apb_resp_t)
  ) i_clint (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .testmode_i(0),
    .apb_req_i(apb_demux_req[cobalt_pkg::CLINT]),
    .apb_rsp_o(apb_demux_rsp[cobalt_pkg::CLINT]),
    .rtc_i(rtc_clk_i),
    .timer_irq_o(timer_irq_o),
    .ipi_o()
  );


  // UART
  apb_uart i_apb_uart (
    .CLK     ( clk_i           ),
    .RSTN    ( rst_ni          ),
    .PSEL    ( apb_demux_req[cobalt_pkg::UART].psel       ),
    .PENABLE ( apb_demux_req[cobalt_pkg::UART].penable    ),
    .PWRITE  ( apb_demux_req[cobalt_pkg::UART].pwrite     ),
    .PADDR   ( apb_demux_req[cobalt_pkg::UART].paddr[4:2] ),
    .PWDATA  ( apb_demux_req[cobalt_pkg::UART].pwdata     ),
    .PRDATA  ( apb_demux_rsp[cobalt_pkg::UART].prdata     ),
    .PREADY  ( apb_demux_rsp[cobalt_pkg::UART].pready     ),
    .PSLVERR ( apb_demux_rsp[cobalt_pkg::UART].pslverr    ),
    .INT     (                 ), // to be connected to PLIC later on 
    .OUT1N   (                 ), // keep open
    .OUT2N   (                 ), // keep open
    .RTSN    (                 ), // no flow control
    .DTRN    (                 ), // no flow control
    .CTSN    ( 1'b0            ),
    .DSRN    ( 1'b0            ),
    .DCDN    ( 1'b0            ),
    .RIN     ( 1'b0            ),
    .SIN     ( rx_i            ),
    .SOUT    ( tx_o            )
);




sysctrl_reg_top_apb i_sysctrl_reg_top_apb (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .PSEL(apb_demux_req[cobalt_pkg::SYSCTRL].psel),
    .PENABLE(apb_demux_req[cobalt_pkg::SYSCTRL].penable),
    .PWRITE(apb_demux_req[cobalt_pkg::SYSCTRL].pwrite),
    .PADDR(apb_demux_req[cobalt_pkg::SYSCTRL].paddr),
    .PWDATA(apb_demux_req[cobalt_pkg::SYSCTRL].pwdata),
    .PSTRB(apb_demux_req[cobalt_pkg::SYSCTRL].pstrb),
    .PRDATA(apb_demux_rsp[cobalt_pkg::SYSCTRL].prdata),
    .PREADY(apb_demux_rsp[cobalt_pkg::SYSCTRL].pready),
    .PSLVERR(apb_demux_rsp[cobalt_pkg::SYSCTRL].pslverr),
    .tohost_q(),
    .chipid_d(32'hC0BA_1701),
    .fromhost_d(32'hC0BA_C0BA),
    .devmode_i(1'b1)
  );



endmodule