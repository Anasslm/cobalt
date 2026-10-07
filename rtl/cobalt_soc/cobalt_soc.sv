module cobalt_soc #(
    parameter type noc_req_t = cobalt_axi::req_t,
    parameter type noc_resp_t = cobalt_axi::resp_t
)
(
    input clk_i,
    input rst_ni,

    input  logic  rx_i,
    output logic  tx_o
);


`include "axi/typedef.svh"

localparam AxiIdWidthMaster = cobalt_axi::IdWidth;
localparam AxiIdWidthSlave  = cobalt_axi::IdWidth + $clog2(cobalt_pkg::NrSlaves);
localparam AxiUserWidth     = cobalt_axi::UserWidth;
localparam xbar_NrSlaves    = cobalt_pkg::NrSlaves;
localparam xbar_NrMasters   = cobalt_pkg::NB_PERIPHERALS;




typedef logic [3:0]   slaves_id_t;
typedef logic [$bits(slaves_id_t)  + $clog2(cobalt_pkg::NrSlaves) -1:0]   masters_id_t;
typedef logic [63:0]  addr_t;
typedef logic [63:0]  data_t;
typedef logic [7:0]   strb_t;
typedef logic [63:0]  user_t;

// define types for slaves and masters of the xbar
`AXI_TYPEDEF_ALL(xbar_slaves, addr_t, slaves_id_t, data_t, strb_t, user_t)
`AXI_TYPEDEF_ALL(xbar_masters, addr_t, masters_id_t, data_t, strb_t, user_t)

xbar_slaves_req_t [xbar_NrSlaves - 1 : 0] xbar_slaves_req;
xbar_slaves_resp_t [xbar_NrSlaves - 1 : 0] xbar_slaves_rsp;

xbar_masters_req_t [xbar_NrMasters - 1 : 0] xbar_masters_req;
xbar_masters_resp_t [xbar_NrMasters - 1 : 0] xbar_masters_rsp;



cpu_subsys  i_cpu_subsys (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_addr_i(cobalt_pkg::ROMBase),
    .hart_id_i(0),
    .irq_i(0),
    .time_irq_i(0),
    .debug_req_i(0),
    .axi_req(xbar_slaves_req[0]),
    .axi_rsp(xbar_slaves_rsp[0])

  );




// ---------------
// AXI Xbar
// ---------------

axi_pkg::xbar_rule_64_t [cobalt_pkg::NB_PERIPHERALS-1:0] addr_map;

assign addr_map = '{
  '{ idx: cobalt_pkg::Debug,    start_addr: cobalt_pkg::DebugBase,    end_addr: cobalt_pkg::DebugBase + cobalt_pkg::DebugLength       },
  '{ idx: cobalt_pkg::ROM,      start_addr: cobalt_pkg::ROMBase,      end_addr: cobalt_pkg::ROMBase + cobalt_pkg::ROMLength           },
  '{ idx: cobalt_pkg::CLINT,    start_addr: cobalt_pkg::CLINTBase,    end_addr: cobalt_pkg::CLINTBase + cobalt_pkg::CLINTLength       },
  '{ idx: cobalt_pkg::PLIC,     start_addr: cobalt_pkg::PLICBase,     end_addr: cobalt_pkg::PLICBase + cobalt_pkg::PLICLength         },
  '{ idx: cobalt_pkg::UART,     start_addr: cobalt_pkg::UARTBase,     end_addr: cobalt_pkg::UARTBase + cobalt_pkg::UARTLength         },
  '{ idx: cobalt_pkg::Timer,    start_addr: cobalt_pkg::TimerBase,    end_addr: cobalt_pkg::TimerBase + cobalt_pkg::TimerLength       },
  '{ idx: cobalt_pkg::SPI,      start_addr: cobalt_pkg::SPIBase,      end_addr: cobalt_pkg::SPIBase + cobalt_pkg::SPILength           },
  '{ idx: cobalt_pkg::Ethernet, start_addr: cobalt_pkg::EthernetBase, end_addr: cobalt_pkg::EthernetBase + cobalt_pkg::EthernetLength },
  '{ idx: cobalt_pkg::GPIO,     start_addr: cobalt_pkg::GPIOBase,     end_addr: cobalt_pkg::GPIOBase + cobalt_pkg::GPIOLength         },
  '{ idx: cobalt_pkg::SRAM,     start_addr: cobalt_pkg::SramBase,     end_addr: cobalt_pkg::SramBase + cobalt_pkg::SRAMLength         }
};


localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
  NoSlvPorts:         cobalt_pkg::NrSlaves,
  NoMstPorts:         cobalt_pkg::NB_PERIPHERALS,
  MaxMstTrans:        1, // Probably requires update
  MaxSlvTrans:        1, // Probably requires update
  FallThrough:        1'b0,
  LatencyMode:        axi_pkg::CUT_ALL_PORTS,
  AxiIdWidthSlvPorts: AxiIdWidthMaster,
  AxiIdUsedSlvPorts:  AxiIdWidthMaster,
  UniqueIds:          1'b0,
  PipelineStages:     1'b0,
  AxiAddrWidth:       cobalt_axi::AddrWidth,
  AxiDataWidth:       cobalt_axi::DataWidth,
  NoAddrRules:        cobalt_pkg::NB_PERIPHERALS
};



axi_xbar #(
  .Cfg            ( AXI_XBAR_CFG              ),
  .slv_aw_chan_t  ( xbar_slaves_aw_chan_t     ),
  .mst_aw_chan_t  ( xbar_masters_aw_chan_t    ),
  .w_chan_t       ( xbar_slaves_w_chan_t      ),
  .slv_b_chan_t   ( xbar_slaves_b_chan_t      ),
  .mst_b_chan_t   ( xbar_masters_b_chan_t     ),
  .slv_ar_chan_t  ( xbar_slaves_ar_chan_t     ),
  .mst_ar_chan_t  ( xbar_masters_ar_chan_t    ),
  .slv_r_chan_t   ( xbar_slaves_r_chan_t      ),
  .mst_r_chan_t   ( xbar_masters_r_chan_t     ),
  .slv_req_t      ( xbar_slaves_req_t         ),
  .slv_resp_t     ( xbar_slaves_resp_t        ),
  .mst_req_t      ( xbar_masters_req_t        ),
  .mst_resp_t     ( xbar_masters_resp_t       ),
  .rule_t         ( axi_pkg::xbar_rule_64_t   )
) i_axi_xbar (
  .clk_i                 ( clk_i              ),
  .rst_ni                ( rst_ni             ),
  .slv_ports_req_i       ( xbar_slaves_req    ),
  .slv_ports_resp_o      ( xbar_slaves_rsp    ),
  .mst_ports_req_o       ( xbar_masters_req   ),
  .mst_ports_resp_i      ( xbar_masters_rsp   ),
  .addr_map_i            ( addr_map           ),
  .en_default_mst_port_i ( '0                 ),
  .default_mst_port_i    ( '0                 )
);



// ---------------
// ROM
// ---------------
logic           rom_req;
logic [63:0]    rom_addr;
logic [63:0]    rom_rdata;

cobalt_axi2mem #(
  .AXI_ID_WIDTH   ( 4                ),
  .AXI_ADDR_WIDTH ( 64               ),
  .AXI_DATA_WIDTH ( 64               ),
  .AXI_USER_WIDTH ( 64               ),
  .req_t           (xbar_masters_req_t),
  .resp_t          (xbar_masters_resp_t)
) i_cobalt_axi2rom (
  .clk_i          ( clk_i                             ),
  .rst_ni         ( rst_ni                            ),
  .axi_req_i      ( xbar_masters_req[cobalt_pkg::ROM] ),
  .axi_resp_o     ( xbar_masters_rsp[cobalt_pkg::ROM] ),
  .req_o          ( rom_req                 ),
  .we_o           (                         ),
  .addr_o         ( rom_addr                ),
  .be_o           (                         ),
  .user_o         (                         ),
  .data_o         (                         ),
  .user_i         ( '0                      ),
  .data_i         ( rom_rdata               )
);

cobalt_boot i_cobalt_bootrom (
  .clk_i      ( clk_i     ),
  .req_i      ( rom_req   ),
  .addr_i     ( rom_addr  ),
  .rdata_o    ( rom_rdata )
);
// ---------------   

// ---------------
// SRAM
// ---------------

logic                sram_req;
logic                sram_we;
logic [63:0]         sram_addr;
logic [7:0]          sram_be;
logic [63:0]         sram_rdata;
logic [63:0]         sram_data;
logic [63:0]         sram_wdata;


xbar_masters_req_t axi_sram_remap_req;

always_comb begin
  axi_sram_remap_req = xbar_masters_req[cobalt_pkg::SRAM];
  axi_sram_remap_req.aw.addr = xbar_masters_req[cobalt_pkg::SRAM].aw.addr - 64'h8000_0000;
  axi_sram_remap_req.ar.addr = xbar_masters_req[cobalt_pkg::SRAM].ar.addr - 64'h8000_0000;
end

  
cobalt_axi2mem #(
  .AXI_ID_WIDTH   ( 4                ),
  .AXI_ADDR_WIDTH ( 64               ),
  .AXI_DATA_WIDTH ( 64               ),
  .AXI_USER_WIDTH ( 64               ),
  .req_t           (xbar_masters_req_t),
  .resp_t          (xbar_masters_resp_t)
) i_cobalt_axi2sram (
  .clk_i          ( clk_i                             ),
  .rst_ni         ( rst_ni                            ),
  .axi_req_i      ( axi_sram_remap_req ),
  .axi_resp_o     ( xbar_masters_rsp[cobalt_pkg::SRAM] ),
  .req_o          ( sram_req                          ),
  .we_o           ( sram_we                           ),
  .addr_o         ( sram_addr                         ),
  .be_o           ( sram_be                           ),
  .user_o         (                                   ),
  .data_o         ( sram_wdata                       ),
  .user_i         ( 0                                 ),
  .data_i         ( sram_rdata                        )
);


tc_sram # (
    .NumWords(8192), // to be changed to reflect current lenght of the sram
    .DataWidth(64),
    .ByteWidth(8),
    .NumPorts(1)
    
  )
  i_tc_sram (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .req_i(sram_req),
    .we_i(sram_we),
    .addr_i(sram_addr[12:3]),
    .wdata_i(sram_wdata),
    .be_i(sram_be),
    .rdata_o(sram_rdata)
  );

///---------------

// ---------------
// UART
// ---------------
logic         uart_penable;
logic         uart_pwrite;
logic [31:0]  uart_paddr;
logic         uart_psel;
logic [31:0]  uart_pwdata;
logic [31:0]  uart_prdata;
logic         uart_pready;
logic         uart_pslverr;  

typedef logic [31:0]  paddr_t;
typedef logic [31:0]  pdata_t;
typedef logic [3:0]   pstrb_t;

// define types for slaves and masters of the xbar
`APB_TYPEDEF_ALL(apb, paddr_t, pdata_t, pstrb_t)

apb_req_t  uart_apb_req;
apb_resp_t uart_apb_rsp;

axi_to_apb # (
    .NoRules(0),
    .AxiAddrWidth(64),
    .AxiDataWidth(64),
    .AxiIdWidth($bits(slaves_id_t)  + $clog2(cobalt_pkg::NrSlaves)),
    .AxiUserWidth(64),
    .ApbAddrWidth(32),
    .ApbDataWidth(32),
    .axi_req_t(xbar_masters_req_t),
    .axi_resp_t(xbar_masters_resp_t),
    .apb_req_t(apb_req_t),
    .apb_resp_t(apb_resp_t)
  )
  i_axi_to_apb (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .axi_req_i(xbar_masters_req[cobalt_pkg::UART]),
    .axi_resp_o(xbar_masters_rsp[cobalt_pkg::UART]),
    .apb_req_o (uart_apb_req),
    .apb_resp_i(uart_apb_rsp),
    .addr_map_i(0)
  );



apb_uart i_apb_uart (
    .CLK     ( clk_i           ),
    .RSTN    ( rst_ni          ),
    .PSEL    ( uart_apb_req.psel       ),
    .PENABLE ( uart_apb_req.penable    ),
    .PWRITE  ( uart_apb_req.pwrite     ),
    .PADDR   ( uart_apb_req.paddr[4:2] ),
    .PWDATA  ( uart_apb_req.pwdata     ),
    .PRDATA  ( uart_apb_rsp.prdata     ),
    .PREADY  ( uart_apb_rsp.pready     ),
    .PSLVERR ( uart_apb_rsp.pslverr    ),
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



endmodule