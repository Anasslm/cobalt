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
// Author: Florian Zaruba, ETH Zurich
// Description: Contains SoC information as constants
package cobalt_pkg;
  // M-Mode Hart, S-Mode Hart
  localparam int unsigned NumTargets = 2;
  // Uart, SPI, Ethernet, reserved
  localparam int unsigned NumSources = 30;
  localparam int unsigned MaxPriority = 7;

  typedef bit [ 7:0] byte_bt; 
  typedef bit [15:0] shrt_bt;
  typedef bit [31:0] word_bt;
  typedef bit [63:0] doub_bt;
  typedef bit [ 9:0] dw_bt;   // data widths
  typedef bit [ 5:0] aw_bt;   // address, ID widths or small buffers  

  localparam NrSlaves = 2; // actually masters, but slaves on the crossbar

  typedef enum int unsigned {
    SRAM     = 0,
  //  GPIO     = 1,
  //  Ethernet = 2,
  //  SPI      = 3,
  //  Timer    = 4,
  //  UART     = 5,
  //  PLIC     = 6,
  //  CLINT    = 7,
    ROM      = 1,
    PERIPH   = 2,
    Debug    = 3
  } axi_slaves_t;

  typedef enum int unsigned {
  
    GPIO     = 7,
    Ethernet = 6,
    SPI      = 5,
    Timer    = 4,
    UART     = 3,
    PLIC     = 2,
    SYSCTRL  = 1,
    CLINT    = 0


  } apb_slaves_t;

  localparam NB_AXI_PERIPHERALS = Debug + 1;
  
  localparam NB_APB_PERIPHERALS = 8; // should change to size of apb_slaves_t enum


  localparam logic[63:0] DebugLength    = 64'h1000;
  localparam logic[63:0] ROMLength      = 64'h10000;
  localparam logic[63:0] CLINTLength    = 64'hC0000;
  localparam logic[63:0] SYSCTRLLength  = 64'h1000;
  localparam logic[63:0] PLICLength     = 64'h3FF_FFFF;
  localparam logic[63:0] UARTLength     = 64'h1000;
  localparam logic[63:0] TimerLength    = 64'h1000;
  localparam logic[63:0] SPILength      = 64'h800000;
  localparam logic[63:0] EthernetLength = 64'h10000;
  localparam logic[63:0] GPIOLength     = 64'h1000;


  localparam logic[63:0] DRAMLength     = 64'h40000000; // 1GByte of DDR (split between two chips on Genesys2)

  localparam logic[63:0] SRAMLength     = 64'h1800000;  // 24 MByte of SRAM
  

  
  // Instantiate AXI protocol checkers
  localparam bit GenProtocolChecker = 1'b0;





  localparam logic[63:0]  CLINTBase    = 64'h0200_0000;
  localparam logic[63:0]  SYSCTRLBase  = 64'h0400_0000;
  localparam logic[63:0]  PLICBase     = 64'h0C00_0000;
  localparam logic[63:0]  UARTBase     = 64'h1000_0000;
  localparam logic[63:0]  TimerBase    = 64'h1800_0000;
  localparam logic[63:0]  SPIBase      = 64'h2000_0000;
  localparam logic[63:0]  EthernetBase = 64'h3000_0000;
  localparam logic[63:0]  GPIOBase     = 64'h4000_0000;

  localparam logic[63:0]  DebugBase    = 64'h0000_0000;
  localparam logic[63:0]  ROMBase      = 64'h0001_0000;
  localparam logic[63:0]  PeriphBase   = CLINTBase;
  localparam logic[63:0]  SramBase     = 64'h8000_0000;



  localparam NrRegion = 1;
  localparam logic [NrRegion-1:0][NB_AXI_PERIPHERALS-1:0] ValidRule = {{NrRegion * NB_AXI_PERIPHERALS}{1'b1}};

  localparam logic[63:0] PeriphLength   = GPIOBase + GPIOLength - CLINTBase; // Length of the peripheral region



endpackage
