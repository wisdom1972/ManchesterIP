`timescale 100ps/10ps
//`define Efinity_Debug

///////////////////////////////////////////////////////////
/**********************************************************
	功能描述：
	
	重要输入信号要求：
	详细设计方案文件编号：
	仿真文件名：
	
	编制：朱仁昌
	创建日期： 2019-9-16
	版本：V1、0
	修改记录：
	
2019-10-2 V1.0
===
正式发布的第一个版本
===
功能：
1、提供系统时钟灵活的MII接口，可以很方便的和内部逻辑链接；
2、将MII转成串行数据，并经LVDS发送Manchester编码；
3、接收Manchester编码的流，进行整形、滤波、定界、译码的算法，最后恢复出数据，并转成MII接口；
4、提取Manchester编码的时钟；时钟抖动小于20ns;
5、测量接收时钟和本地时钟的误差，测量精度0.25ppm；
6、精密的容错算法和码流跟踪算法，可达大于200ppm的频率偏差容限；（与信号质量有关）

模块资源占用情况
=============================== 
EFX_ADD         : 	183
EFX_LUT4        : 	341
EFX_FF          : 	388
EFX_RAM_5K      : 	3
EFX_GBUFCE      : 	4
=============================== 
676LEs  3BRAMs 

模块性能：
=======================================================
Clock Name      Period (ns)   Frequency (MHz)   Edge
SysClk              6.270         159.496     (R-R)
TxMcstClk           4.275         233.920     (R-R)
RxMcstClk           7.546         132.512     (R-R)
=======================================================

较上个版本：
1、去掉了多余的DPLL等实际使用中基本不用的模块；
2、提高了时钟恢复时钟的性能；
3、去掉了Debuger里平时使用的很少的信号


2019-10-2 V1.1
===
1、增加了MII环回功能；
2、在VIO中增加了CtrlMiiLoop的信号；
3、增加了对没有数据的判断，如果数据不连续，D0闪，最后的状态Right无效快闪

2020-01-14 V1.2
===
1、去掉了调试代码；
2、优化了代码，减少了近200LEs；
3、把Tx和Rx分开；

=============================== 
EFX_ADD         : 	67
EFX_LUT4        : 	260
EFX_FF          : 	296
EFX_RAM_5K      : 	3
EFX_GBUFCE      : 	3
=============================== 

**********************************************************/

module Mcst2MII
(   
	//System Signal
	SysClk		  ,	//(I)System Clock
	TxMcstClk   , //(I)Manchester Tx clock
	RxMcstClk   , //(I)Manchester Rx clock
	Reset_N     ,	//System Reset
	//MII Signal
	MiiRxCEn    , //(O)MII Rx Clock Enable
	MiiRxData   , //(O)MII Rx Data Input
	MiiRxDV     , //(O)MII Rx Data Valid
	MiiRxErr    , //(O)MII Rx Error
	MiiTxCEn    , //(O)MII Tx Clock Enable
	MiiTxData   , //(I)MII Tx Data Output
	MiiTxEn     , //(I)MII Tx Enable
	MiiTxBusy   , //(O)MII Tx Busy
	//Manchester Data In/Output
	TxMcstData  , //(O)Manchester Data Output
	RxMcstData  , //(I)Manchester Data In
	RxMcstLink    //(O)Manchester Linked
);

 	//Define  Parameter
	/////////////////////////////////////////////////////////
	parameter		TCo_C   		  = 1;     
	
	/////////////////////////////////////////////////////////
	//System Signal
	input 	      SysClk    ;	//系统时钟
	input         TxMcstClk ; //(I)Manchester Tx clock
	input         RxMcstClk ; //(I)Manchester Rx clock
	input					Reset_N   ;	//系统复位
	
	/////////////////////////////////////////////////////////
	//MII Signal
	output        MiiRxCEn  ; //(O)MII Rx Clock Enable
	output  [3:0] MiiRxData ; //(O)MII Rx Data Input
	output        MiiRxDV   ; //(O)MII Rx Data Valid
	output        MiiRxErr  ; //(O)MII Rx Error
	output        MiiTxCEn  ; //(O)MII Tx Clock Enable
	input   [3:0] MiiTxData ; //(I)MII Tx Data Output
	input         MiiTxEn   ; //(I)MII Tx Enable
	output        MiiTxBusy ; //(O)MII Tx Busy
	
	/////////////////////////////////////////////////////////
	//Manchester Data In/Output
	output  [ 7:0]  TxMcstData  ; //(O)Manchester Data Output
	input   [ 7:0]  RxMcstData  ; //(I)Manchester Data In
	output          RxMcstLink  ; //(O)Manchester Linked
		
//1111111111111111111111111111111111111111111111111111111
//	
//	Input：
//	output：
//***************************************************/ 

	/////////////////////////////////////////////////////////
	reg   [2:0]   TxByteGen   = 3'h0;
	
	always @( posedge TxMcstClk)  TxByteGen <= # TCo_C TxByteGen + 3'h1;
	
	/////////////////////////////////////////////////////////
	reg   [1:0] TxByteClkReg  = 2'h0;
	reg					MiiTxCEn      = 1'h0;
	
	always @( posedge SysClk)  TxByteClkReg <= # TCo_C {TxByteClkReg[0],TxByteGen[2]};
	always @( posedge SysClk)  MiiTxCEn     <= # TCo_C  (^TxByteClkReg);
	
	/////////////////////////////////////////////////////////
	wire  [7:0] TxMcstData  ; //(O)Manchester Data Output
	wire        MiiTxBusy   ; //(O)MII Tx Busy
	
	McstTx          U1_McstTx
  (   
  	//System Signal
  	.SysClk			 (SysClk  ),	//System Clock
  	.TxMcstClk   (TxMcstClk ),  //(I)Manchester Tx clock
  	.Reset_N     (Reset_N   ),  //System Reset
  	//MII Signal
  	.MiiTxCEn    (MiiTxCEn  ),  //(I)MII Tx Clock Enable
  	.MiiTxData   (MiiTxData ),  //(I)MII Tx Data Output
  	.MiiTxEn     (MiiTxEn   ),  //(I)MII Tx Enable
	  .MiiTxBusy   (MiiTxBusy ),  //(O)MII Tx Busy
  	//Manchester Data In/Output
  	.TxMcstData  (TxMcstData)   //(O)Manchester Data Output
  );
  
//1111111111111111111111111111111111111111111111111111111



//22222222222222222222222222222222222222222222222222222
//	
//	Input：
//	output：
//***************************************************/ 

	/////////////////////////////////////////////////////////
	wire        MiiRxCEn    ; //(O)MII Rx Clock Enable
	wire  [3:0] MiiRxData   ; //(O)MII Rx Data Input
	wire        MiiRxDV     ; //(O)MII Rx Data Valid
	//Manchester Signal
	wire  [ 2:0] RxDmlitPos ; //(O)Delimite Position	
	wire  [ 7:0] RxMcstCode ; //(O)Mancheste Code Output
	wire         RxNrzDRst  ; //(O)Rx Not-Return-to-Zero Data Restore
	wire  [ 1:0] RxNrzFRst  ; //(O)Rx Not-Return-to-Zero Flag
	wire  [2:0]  RxClkAdj   ; //(O)Rx Clock Adjust Signal
	                            //[1]: AdjustEn; [0]:AjustDir, 1 faster;0 Slower	 	
	wire         RxMcstLink ; //(O)Manchester Linked
	
	McstRx  	      U2_McstRx
  (   
  	//System Signal
  	.SysClk      (SysClk    ),  //System Clock
  	.Reset_N     (Reset_N   ),  //System Reset
  	.RxMcstClk   (RxMcstClk ),  //(I)Manchester Rx clock
  	//MII Signal
  	.MiiRxCEn    (MiiRxCEn  ),  //(O)MII Rx Clock Enable
  	.MiiRxData   (MiiRxData ),  //(O)MII Rx Data Input
  	.MiiRxDV     (MiiRxDV   ),  //(O)MII Rx Data Valid
	  .MiiRxErr    (MiiRxErr  ),  //(O)MII Rx Error
  	//Manchester Signal         
  	.RxMcstData  (RxMcstData),  //(I)Manchester Data In
	  .RxMcstLink  (RxMcstLink),  //(O)Manchester Linked
	  .RxRstClk    (RxRstClk  )   //(O)Rx Restore Clock
  );
  
//22222222222222222222222222222222222222222222222222222


endmodule 







