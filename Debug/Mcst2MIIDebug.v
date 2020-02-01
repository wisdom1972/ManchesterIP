`timescale 100ps/10ps

`include	"PlcCommBusParamDefine.v"

///////////////////////////////////////////////////////////
/**********************************************************
	功能描述：
	
	重要输入信号要求：
	详细设计方案文件编号：
	仿真文件名：
	
	编制：朱仁昌
	创建日期： 2019-9-9
	版本：V1、0
	修改记录：
**********************************************************/

module  Mcst2MIIDebug
(   
	//Check Resultwire 
`ifdef  Efinity_Debug	 //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  
	jtag_inst1_CAPTURE,  
	jtag_inst1_DRCK,     
	jtag_inst1_RESET,    
	jtag_inst1_RUNTEST,  
	jtag_inst1_SEL,      
	jtag_inst1_SHIFT,    
	jtag_inst1_TCK,      
	jtag_inst1_TDI,      
	jtag_inst1_TMS,      
	jtag_inst1_UPDATE,   
	jtag_inst1_TDO,    
`endif  //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& 
	//System Signal
	SysClk			,	//(I)System Clock
	TxMcstClk   , //(I)Manchester Tx clock
	RxMcstClk   , //(I)Manchester Rx clock
	PllLocked		,	//(I)PLL Locked
	//Manchester Data In/Output
	TxMcstData  , //(O)Manchester Data Output
	RxMcstData  , //(I)Manchester Data Input	
	//Other
	LED           //(O)LED
);

 	//Define  Parameter
	/////////////////////////////////////////////////////////
	parameter		TCo_C   		= 100;    
	
	parameter		RightCntWidth_C 	  = 27; 
	
	parameter   TxDataBurstLength_C = 100;
	parameter   TxDataIntervalLen_C = 20;
	
	/////////////////////////////////////////////////////////
	
	//Define Port
`ifdef  Efinity_Debug	 //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  
  input  jtag_inst1_CAPTURE ;
  input  jtag_inst1_DRCK    ;
  input  jtag_inst1_RESET   ;
  input  jtag_inst1_RUNTEST ;
  input  jtag_inst1_SEL     ;
  input  jtag_inst1_SHIFT   ;
  input  jtag_inst1_TCK     ;
  input  jtag_inst1_TDI     ;
  input  jtag_inst1_TMS     ;
  input  jtag_inst1_UPDATE  ;
  output jtag_inst1_TDO     ;
  
`endif  //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& 
	/////////////////////////////////////////////////////////
	//System Signal
	input 	      SysClk    ;	//ϵͳʱ��
	input   [2:0] PllLocked	;	//PLL Locked
	input         TxMcstClk ; //(I)Manchester Tx clock
	input         RxMcstClk ; //(I)Manchester Rx clock
	
	/////////////////////////////////////////////////////////
	//Manchester Data In/Output
	output  [7:0] TxMcstData ; //(O)Manchester Data Output
	input   [7:0] RxMcstData  ; //(I)Manchester Data Input	
	
	/////////////////////////////////////////////////////////
	//Other Signal
	output	[7:0]	LED;
	                              
	/////////////////////////////////////////////////////////
	wire  Reset_N     = PllLocked[0];
	wire  McstTxRst_N = PllLocked[1];
	wire  McstRxRst_N = PllLocked[2];
		
//1111111111111111111111111111111111111111111111111111111
//	
//	Input��
//	output��
//***************************************************/ 
	/////////////////////////////////////////////////////////
	wire  			TxClkEn;
	
	reg					TxDataEn  =  1'h0;
	reg [15:0]  TxDataLenCnt = 16'h0;
	reg [15:0]  TxItvlLenCnt = 16'h0;
	
	always @( posedge SysClk or negedge McstTxRst_N)
	begin
		if (!McstTxRst_N)
		begin
			TxDataEn	    <= # TCo_C  1'h0;
			TxDataLenCnt  <= # TCo_C 16'h1;
			TxItvlLenCnt	<= # TCo_C 16'h0;
		end
		else if (TxClkEn)
		begin
  		if (TxDataEn)   
  	  begin
  	    TxDataEn      <= # TCo_C |TxDataLenCnt        ;
  	    TxItvlLenCnt  <= # TCo_C TxDataIntervalLen_C  ;
  	    TxDataLenCnt  <= # TCo_C TxDataLenCnt - 16'h1 ;
  	  end
  	  else            
  	  begin
  	    TxDataEn      <= # TCo_C (TxItvlLenCnt == 2'h0) ;
  	    TxItvlLenCnt  <= # TCo_C TxItvlLenCnt - 16'h1   ;
  	    TxDataLenCnt  <= # TCo_C TxDataBurstLength_C    ;
      end
    end
	end
	
	/////////////////////////////////////////////////////////
	wire	PrbsTxClkEn = TxDataEn & TxClkEn;
	
	wire	[3:0]  PrbsDataOut;
		
	PRBS9GenX4	U1_PRBSGen	
	(
		//System Signal
		.SysClk		(SysClk   ),	//System Clock
		.Reset_N	(McstTxRst_N),	//System Reset
		//Signal
		.ClkEn		(PrbsTxClkEn),	//Clock Enable
		.DataOut	(PrbsDataOut)		//Data Output
	);
	
	/////////////////////////////////////////////////////////
	wire        CtrlMiiLoop ;
	wire  [3:0] LpMiiTxData ; //(O)MII Tx Data Output
	wire        LpMiiTxEn   ; //(O)MII Tx Enable
	
	wire  [3:0] MiiTxData   = CtrlMiiLoop ? LpMiiTxData : PrbsDataOut ; //(I)MII Tx Data Output //{4{TxDataCnt[0]}} ;
	wire        MiiTxEn     = CtrlMiiLoop ? LpMiiTxEn   : TxDataEn    ; //(I)MII Tx Enable
	
//1111111111111111111111111111111111111111111111111111111



//22222222222222222222222222222222222222222222222222222
//	
//	Input��
//	output��
//***************************************************/ 
	wire  [ 7:0] McstCodeIn ; //(O)Mancheste Code Input
	
	assign  McstCodeIn[0] = RxMcstData[7];
	assign  McstCodeIn[1] = RxMcstData[6];
	assign  McstCodeIn[2] = RxMcstData[5];
	assign  McstCodeIn[3] = RxMcstData[4];
	assign  McstCodeIn[4] = RxMcstData[3];
	assign  McstCodeIn[5] = RxMcstData[2];
	assign  McstCodeIn[6] = RxMcstData[1];
	assign  McstCodeIn[7] = RxMcstData[0];
	
	/////////////////////////////////////////////////////////
	//MII Signal
	wire          MiiRxCEn    ; //(O)MII Rx Clock Enable
	wire  [3:0]   MiiRxData   ; //(O)MII Rx Data Input
	wire          MiiRxDV     ; //(O)MII Rx Data Valid
	wire          MiiRxErr    ; //(O)MII Rx Error
	wire          MiiTxCEn    ; //(O)MII Tx Clock Enable
	wire          MiiTxBusy   ; //(O)MII Tx Busy	
	//Manchester Data In/Output
	wire          RxMcstLink  ; //(O)Manchester Linked
	wire  [ 7:0]  TxMcstData  ; //(O)Manchester Data Output	
	
	Mcst2MII  U2_Mcst2MII
  (   
  	//System Signal
  	.SysClk			 (SysClk		  ),	//(I)System Clock
  	.TxMcstClk   (TxMcstClk   ),  //(I)Manchester Tx clock
  	.RxMcstClk   (RxMcstClk   ),  //(I)Manchester Rx clock
  	.Reset_N     (Reset_N     ),	//(I)System Reset
  	//MII Signal
  	.MiiRxCEn    (MiiRxCEn    ),  //(O)MII Rx Clock Enable
  	.MiiRxData   (MiiRxData   ),  //(O)MII Rx Data Input
  	.MiiRxDV     (MiiRxDV     ),  //(O)MII Rx Data Valid
	  .MiiRxErr    (MiiRxErr    ),  //(O)MII Rx Error
  	.MiiTxCEn    (MiiTxCEn    ),  //(O)MII Tx Clock Enable
  	.MiiTxData   (MiiTxData   ),  //(I)MII Tx Data Output
  	.MiiTxEn     (MiiTxEn     ),  //(I)MII Tx Enable
	  .MiiTxBusy   (MiiTxBusy   ),  //(O)MII Tx Busy
  	//Manchester Data In/Output
  	.TxMcstData  (TxMcstData  ), //(O)Manchester Data Output
  	.RxMcstData  (RxMcstData  ), //(I)Manchester Data In
  	.RxMcstLink  (RxMcstLink  )  //(O)Manchester Linked
  );
			
	/////////////////////////////////////////////////////////
	assign  TxClkEn = MiiTxCEn;	  
	 
//22222222222222222222222222222222222222222222222222222



//3333333333333333333333333333333333333333333333333333333
//	
//	Input��
//	output��
//***************************************************/ 

//3333333333333333333333333333333333333333333333333333333



//4444444444444444444444444444444444444444444444444444444
//	
//	Input��
//	output��
//***************************************************/ 

	/////////////////////////////////////////////////////////		
	wire 				PrbsRxClkEn	= MiiRxCEn & MiiRxDV;
	wire	[3:0]	PrbsDataIn	= MiiRxData;
		
//	wire 				PrbsRxClkEn	= MiiTxCEn & MiiTxEn;
//	wire	[3:0]	PrbsDataIn	= MiiTxData;
	
	wire				PrbsError;
	wire				PrbsRight;
	
	PRBS9ChkX4 # (.RightCntWidth_C(RightCntWidth_C))
	U0_PRBS9Chk
	(
		//System Signal
		.SysClk  (SysClk    ),  //(I)System Clock
		.Reset_N (Reset_N   ),  //(I)System Reset
		//Signal
		.DataIn	(PrbsDataIn	),	//(I)Data Input
		.ClkEn 	(PrbsRxClkEn),	//(I)Clock Enable
		.Error 	(PrbsError	),	//(O)Data Error
		.Right	(PrbsRight	) 	//(O)Data Right
	);
	
	/////////////////////////////////////////////////////////		
	wire        LedCntRst;
	reg  [3:0]	PrbsErrCnt = 4'h0;
	reg					PrbsRightReg;
	
	always @ (posedge SysClk)
	begin
		PrbsRightReg <= # TCo_C PrbsRight;
		
		if (LedCntRst)    PrbsErrCnt <= # TCo_C {3'h0,PrbsRight};
		else if (PrbsRight ^ PrbsRightReg)
		begin
			PrbsErrCnt <= # TCo_C PrbsErrCnt + {3'h0 , ~&PrbsErrCnt};
		end
	end
	
	/////////////////////////////////////////////////////////
	reg   [23:0]  DataContCnt;
	
	always @( posedge SysClk)  
	begin
	  if (PrbsRxClkEn)    DataContCnt  <= 24'h0;
	  else                DataContCnt  <= DataContCnt + {23'h0, ~DataContCnt[23]};
  end
 
  wire    DataContinue = ~DataContCnt[23];
  
	/////////////////////////////////////////////////////////
	
	
	wire        LpMiiRxCEn  = MiiRxCEn  ; //(I)MII Rx Clock Enable
	wire  [3:0] LpMiiRxData = MiiRxData ; //(I)MII Rx Data Input
	wire        LpMiiRxDV   = MiiRxDV   ; //(I)MII Rx Data Valid
	wire        LpMiiTxCEn  = MiiTxCEn  ; //(I)MII Tx Clock Enable
		
	MiiDataBuff  
	# (
	    .DataWidth_C  (4),
	    .DataDepth_C  (8)
	  )
	U4_LoopBuff
  (   
  	//System Signal
  	.Reset_N      (Reset_N      ), 	//System Reset
  	//Input Port	            
  	.InClock      (SysClk       ),  //(I)Input  Clock 
  	.InMiiClkEn	  (LpMiiRxCEn   ),  //(I)Input  Clock Enable For MII
  	.InMiiDataEn	(LpMiiRxDV	  ),  //(I)Input  Data Enable For MII (TxEn or RxDv)
  	.InMiiData    (LpMiiRxData  ),  //(I)Input  Data For MII
  	.InMiiBusy    (             ), //(O)Input  Busy
  	//Output Port	            
  	.OutClock     (SysClk       ),  //(I)output Clock 
  	.OutMiiClkEn  (LpMiiTxCEn   ),	//(I)output Clock Enable For MII
  	.OutMiiDataEn (LpMiiTxEn    ),	//(O)output Data Enable For MII (TxEn or RxDv)
  	.OutMiiData   (LpMiiTxData  ),	//(O)output Data For MII
  	.OutMiiSync   (             ),  //(O)Output Synchronous Signal
	  .OutMiiEmpty  (             )   //(O)output Mii Buffer Empty
  );
  
	/////////////////////////////////////////////////////////+
		
//4444444444444444444444444444444444444444444444444444444



//5555555555555555555555555555555555555555555555555555555
//	
//	Input��
//	output��
//***************************************************/ 

	/////////////////////////////////////////////////////////		
	reg	[25:0]	LedFlashCnt;
	
	always @( posedge SysClk or negedge Reset_N)
	begin
		if (!Reset_N) LedFlashCnt	<= # TCo_C 26'h0;
		else 					LedFlashCnt	<= # TCo_C LedFlashCnt + 26'h1;     
	end
				
	reg	[25:0]	LedFlashCntA;
	
	always @( posedge TxMcstClk or negedge McstTxRst_N)
	begin
		if (!McstTxRst_N) LedFlashCntA	<= # TCo_C 26'h0;
		else 					    LedFlashCntA	<= # TCo_C LedFlashCntA + 26'h1;     
	end
				
	/////////////////////////////////////////////////////////		
	wire	[7:0]	LED;
	
	assign LED[7]  =   LedFlashCnt[25];
	assign LED[6]  =  ~LedFlashCntA[25];
	
	assign LED[5] 	= ~PrbsError  ;
	assign LED[4] 	= ~RxMcstLink ;
	
	assign LED[3:1]	= ~PrbsErrCnt[3:1];
	assign LED[  0]	= PrbsRight 
	              ? (DataContinue ? 1'h0 : LedFlashCnt[22])
	              : (DataContinue ? 1'h1 : LedFlashCnt[25]);
	
//5555555555555555555555555555555555555555555555555555555


`ifdef  Efinity_Debug	 //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  

	/////////////////////////////////////////////////////////
  reg  [4:0]  DbgTxData;
  
  always @( posedge SysClk)  
  begin
    if (MiiTxCEn)  
    begin
      DbgTxData[  4] <= # TCo_C MiiTxEn;
      DbgTxData[3:0] <= # TCo_C MiiTxData;
    end
  end
  
  reg [1:0]   DegTxClkCnt;
  
  always @( posedge SysClk)  
  begin
    if (MiiTxCEn)             DegTxClkCnt <= # TCo_C 2'h3;
    else if (DegTxClkCnt[1])  DegTxClkCnt <= # TCo_C DegTxClkCnt - 2'h1;
  end
  
  reg   [1:0]  TxClkEnReg    = 2'h0;
  always @( posedge RxMcstClk)  TxClkEnReg <= # TCo_C {TxClkEnReg[0],DegTxClkCnt[1]};
  
  wire         DbgMiiTxCEn   = (TxClkEnReg == 2'h1);
  reg   [3:0]  DbgMiiTxData  = 4'h0;
  reg          DbgMiiTxEn    = 1'h0; 
  
  always @( posedge RxMcstClk)  if (DbgMiiTxCEn)  DbgMiiTxEn    <= # TCo_C DbgTxData[  4];
  always @( posedge RxMcstClk)  if (DbgMiiTxCEn)  DbgMiiTxData  <= # TCo_C DbgTxData[3:0];
  
  reg   [1:0]   DbgTxMcstData;
  
  always @( posedge RxMcstClk)    DbgTxMcstData   = TxMcstData[4:3];
  
	/////////////////////////////////////////////////////////
  wire          jtag_inst1_TDO;
                                                       
	/////////////////////////////////////////////////////////
  wire         DPLLTest_clk           = SysClk      ;
                                           
  wire  [ 0:0] DPLLTest_PrbsError     = PrbsError   ;
  wire  [ 0:0] DPLLTest_PrbsRight     = PrbsRight   ;
  
  wire  [ 0:0] DPLLTest_LedCntRst     ;
  wire  [ 0:0] DPLLTest_ControlMiiLoop;
    
	/////////////////////////////////////////////////////////
  wire        Mcst2MII_clk            = RxMcstClk     ;
                                                      
  wire  [ 1:0] Mcst2MII_TxMcstData    = DbgTxMcstData ;
  wire  [ 0:0] Mcst2MII_MiiTxCEn      = DbgMiiTxCEn   ;
  wire  [ 3:0] Mcst2MII_MiiTxData     = DbgMiiTxData  ;
  wire  [ 0:0] Mcst2MII_MiiTxEn       = DbgMiiTxEn    ;
  wire  [ 0:0] Mcst2MII_MiiRxCEn      = MiiRxCEn      ;
  wire  [ 3:0] Mcst2MII_MiiRxData     = MiiRxData     ;
  wire  [ 0:0] Mcst2MII_MiiRxDV       = MiiRxDV       ;
  wire  [ 0:0] Mcst2MII_PrbsError     = PrbsError     ;
    
	/////////////////////////////////////////////////////////
	edb_top edb_top_inst (
	////////////////
    .bscan_CAPTURE      ( jtag_inst1_CAPTURE ),
    .bscan_DRCK         ( jtag_inst1_DRCK ),
    .bscan_RESET        ( jtag_inst1_RESET ),
    .bscan_RUNTEST      ( jtag_inst1_RUNTEST ),
    .bscan_SEL          ( jtag_inst1_SEL ),
    .bscan_SHIFT        ( jtag_inst1_SHIFT ),
    .bscan_TCK          ( jtag_inst1_TCK ),
    .bscan_TDI          ( jtag_inst1_TDI ),
    .bscan_TMS          ( jtag_inst1_TMS ),
    .bscan_UPDATE       ( jtag_inst1_UPDATE ),
    .bscan_TDO          ( jtag_inst1_TDO ),
	////////////////
    .DPLLTest_clk           ( DPLLTest_clk            ),
    .DPLLTest_PrbsError     ( DPLLTest_PrbsError      ),
    .DPLLTest_PrbsRight     ( DPLLTest_PrbsRight      ),
    .DPLLTest_LedCntRst     ( DPLLTest_LedCntRst      ),
    .DPLLTest_ControlMiiLoop( DPLLTest_ControlMiiLoop ),
     
	////////////////
    .Mcst2MII_clk           ( Mcst2MII_clk        ),
    .Mcst2MII_TxMcstData    ( Mcst2MII_TxMcstData ),
    .Mcst2MII_MiiTxCEn      ( Mcst2MII_MiiTxCEn   ),
    .Mcst2MII_MiiTxData     ( Mcst2MII_MiiTxData  ),
    .Mcst2MII_MiiTxEn       ( Mcst2MII_MiiTxEn    ),
    .Mcst2MII_MiiRxCEn      ( Mcst2MII_MiiRxCEn   ),
    .Mcst2MII_MiiRxData     ( Mcst2MII_MiiRxData  ),
    .Mcst2MII_MiiRxDV       ( Mcst2MII_MiiRxDV    ),
    .Mcst2MII_PrbsError     ( Mcst2MII_PrbsError  )
 );
                     
  assign LedCntRst      = DPLLTest_LedCntRst      ;      
  assign CtrlMiiLoop    = DPLLTest_ControlMiiLoop ;  
  
`else   //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&  
  assign LedCntRst      =  1'h0 ;    
  assign CtrlMiiLoop    =  1'h0 ;    
  
`endif  //&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& 

endmodule 