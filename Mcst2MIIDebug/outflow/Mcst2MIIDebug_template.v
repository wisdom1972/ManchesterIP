
// Efinity Top-level template
// Version: 2019.3.272
// Date: 2020-02-01 21:48

// Copyright (C) 2017 - 2019 Efinix Inc. All rights reserved.

// This file may be used as a starting point for Efinity synthesis top-level target.
// The port list here matches what is expected by Efinity constraint files generated
// by the Efinity Interface Designer.

// To use this:
//     #1)  Save this file with a different name to a different directory, where source files are kept.
//              Example: you may wish to save as C:\Efinity\2019.3\project\Mcst2MIIDebug\Mcst2MIIDebug.v
//     #2)  Add the newly saved file into Efinity project as design file
//     #3)  Edit the top level entity in Efinity project to:  Mcst2MIIDebug
//     #4)  Insert design content.


module Mcst2MIIDebug
(
  input SysClk,
  input RxMcstSClk,
  input jtag_inst1_RUNTEST,
  input jtag_inst1_DRCK,
  input RxMcstClk,
  input RxTestClk,
  input jtag_inst1_SHIFT,
  input TxMcstSClk,
  input DPllRefClk,
  input [7:0] RxMcstData,
  input TxMcstSClkA,
  input jtag_inst1_CAPTURE,
  input jtag_inst1_TCK,
  input TxSysClk,
  input TxMcstClk,
  input jtag_inst1_SEL,
  input TxSysClkA,
  input Clk50MIn,
  input TxMcstClkA,
  input jtag_inst1_RESET,
  input jtag_inst1_TDI,
  input [2:0] PllLocked,
  input jtag_inst1_TMS,
  input jtag_inst1_UPDATE,
  input LvdsTxClk,
  output [7:0] LED,
  output [7:0] TxMcstData,
  output [7:0] DPllLvdsClk,
  output jtag_inst1_TDO
);


endmodule

