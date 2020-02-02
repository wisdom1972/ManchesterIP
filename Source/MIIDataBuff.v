`timescale 100ps/10ps
//`define Efinity_Debug

///////////////////////////////////////////////////////////
/**********************************************************
	功能描述：

	重要输入信号要求：
	详细设计方案文件编号：
	仿真文件名：

	编制：朱仁昌
	创建日期： 2019-10-9
	版本：V1、0
	修改记录：
**********************************************************/

module  MiiDataBuff
(
	//System Signal
	Reset_N     ,	//System Reset
	//Input Port
	InClock     , //(I)Input  Clock
	InMiiClkEn	,	//(I)Input  Clock Enable For MII
	InMiiDataEn	,	//(I)Input  Data Enable For MII (TxEn or RxDv)
	InMiiData   ,	//(I)Input  Data For MII
	InMiiBusy   , //(O)Input  Busy
	//Output Port
	OutClock    , //(I)output Clock
	OutMiiClkEn	,	//(I)output Clock Enable For MII
	OutMiiDataEn,	//(O)output Data Enable For MII (TxEn or RxDv)
	OutMiiData  ,	//(O)output Data For MII
	OutMiiSync  , //(O)Output Synchronous Signal
	OutMiiEmpty   //(O)output Mii Buffer Empty
);

 	//Define  Parameter
	/////////////////////////////////////////////////////////
	parameter		TCo_C   		= 1;

	parameter   DataWidth_C = 8;
	parameter   DataDepth_C = 4;

	localparam  AddrCntWidth_C  = $clog2(DataDepth_C);
	localparam  DataCntWidth_C  = $clog2(DataWidth_C+1);
	localparam  BuffBitNum_C    = (DataWidth_C + 1) * DataDepth_C;
	localparam  SycnDataNum_C   = DataDepth_C/2+1;

	localparam  DW_C  = DataWidth_C    ;
	localparam  DD_C  = DataDepth_C    ;
	localparam  DCW_C = DataCntWidth_C ;
	localparam  ACW_C = AddrCntWidth_C ;
	localparam  BBN_C = BuffBitNum_C   ;
	localparam  SDN_C = SycnDataNum_C  ;


	/////////////////////////////////////////////////////////

	//Define Port
	/////////////////////////////////////////////////////////
	//System Signal
	input					Reset_N   ;			//System Reset

	/////////////////////////////////////////////////////////
	//Input Port
	input               InClock     ; //(I)Input  Clock
	input               InMiiClkEn	;	//(I)Input  Clock Enable For MII
	input               InMiiDataEn	;	//(I)Input  Data Enable For MII (TxEn or RxDv)
	input   [DW_C-1:0]  InMiiData   ;	//(I)Input  Data For MII
  output              InMiiBusy   ; //(O)Input  Busy

	/////////////////////////////////////////////////////////
	//Output Port
	input               OutClock    ; //(I)output Clock
	input               OutMiiClkEn	;	//(I)output Clock Enable For MII
	output              OutMiiDataEn;	//(O)output Data Enable For MII (TxEn or RxDv)
	output  [DW_C-1:0]  OutMiiData  ;	//(O)output Data For MII
  output              OutMiiSync  ; //(O)Output Synchronous Signal
	output              OutMiiEmpty ; //(O)output Mii Buffer Empty


//1111111111111111111111111111111111111111111111111111111
//
//	Input：
//	output：
//***************************************************/

	/////////////////////////////////////////////////////////

	reg [DW_C:0]  FifoWrData = {DW_C+1{1'h0}};

	always @( posedge InClock)
	begin
	  if (InMiiClkEn)
	  begin
	    FifoWrData[DW_C    ]  <= # TCo_C InMiiDataEn;
	    FifoWrData[DW_C-1:0]  <= # TCo_C InMiiData;
    end
  end

  wire InMiiDataAva = FifoWrData[DW_C];

	/////////////////////////////////////////////////////////
	//Write Signal must delay one clock from WrAddrSync, So the FifoWrEn need Pipeline two Clock
  reg           InMiiBusy     = 1'h0;     //(O)Input  Busy
	reg   [1:0]   FifoWrSftReg  = 2'h0;

	always @( posedge InClock)  FifoWrSftReg <= # TCo_C {FifoWrSftReg[0],InMiiClkEn};

	wire   FifoWrEn = FifoWrSftReg[1];// & (~InMiiBusy);

	/////////////////////////////////////////////////////////
	reg   WrAddrSync  = 1'h0;

	always @( posedge InClock)  WrAddrSync <= # TCo_C (~InMiiDataAva & InMiiDataEn) & InMiiClkEn;

	/////////////////////////////////////////////////////////
  reg [ACW_C:0] FifoWrAddrCnt = {ACW_C+1{1'h0}};

  always @( posedge InClock or negedge Reset_N)
  begin
    if (~Reset_N)         FifoWrAddrCnt <= # TCo_C {ACW_C+1{1'h0}};
    else if (WrAddrSync)  FifoWrAddrCnt <= # TCo_C {{ACW_C{1'h0}},1'h1};
    else if (FifoWrEn)    FifoWrAddrCnt <= # TCo_C FifoWrAddrCnt  + {{ACW_C{1'h0}},1'h1};
  end

  wire  [ACW_C-1:0] FifoWrAddr = FifoWrAddrCnt[ACW_C-1:0];

	/////////////////////////////////////////////////////////
  reg   [BBN_C-1:0] FifoDataBuff = {ACW_C{1'h0}};

  integer  i,m;
  always @( posedge InClock or negedge Reset_N)
  begin
    if (~Reset_N)             FifoDataBuff  <= # TCo_C {BBN_C{1'h0}};
    else if (FifoWrEn )
    begin
      for(i=0;i<DD_C;i=i+1)
      begin
        if (FifoWrAddr == i)
        begin
          for (m=0;m<DW_C+1;m=m+1)
          begin
            FifoDataBuff[i*(DW_C+1)+m]  <= # TCo_C FifoWrData[m];
          end
        end
      end
    end
  end

//1111111111111111111111111111111111111111111111111111111



//22222222222222222222222222222222222222222222222222222
//
//	Input：
//	output：
//***************************************************/

	/////////////////////////////////////////////////////////
	reg     OutMiiEmpty = 1'h0 ; //(O)output Mii Buffer Empty
	wire    FifoRdEn    =  OutMiiClkEn;// & (~OutMiiEmpty);

	/////////////////////////////////////////////////////////
	reg [1:0]   InMiiDataEnReg = 2'h0;

	always @( posedge OutClock)  InMiiDataEnReg <= # TCo_C {InMiiDataEnReg[0],InMiiDataAva};

	wire    RdAddrSync  = (InMiiDataEnReg == 2'h1);
  wire    OutMiiSync  = (InMiiDataEnReg == 2'h1);  //(O)Output Synchronous Signal

	/////////////////////////////////////////////////////////
  reg [ACW_C:0] FifoRdAddrCnt = {ACW_C+1{1'h0}};

  always @( posedge OutClock or negedge Reset_N)
  begin
    if (~Reset_N)         FifoRdAddrCnt <= # TCo_C {ACW_C+1{1'h0}};
    else if (RdAddrSync)  FifoRdAddrCnt <= # TCo_C SycnDataNum_C;
    else if (FifoRdEn)    FifoRdAddrCnt <= # TCo_C FifoRdAddrCnt  + {{ACW_C{1'h0}},1'h1};
  end

  wire  [ACW_C-1:0]  FifoRdAddr = FifoRdAddrCnt[ACW_C-1:0];

	/////////////////////////////////////////////////////////
	reg [8:0] FifoRdData = 9'h0;

  integer  j,n;
	always @( posedge OutClock)
	begin
	  if (FifoRdEn)
	  begin
      for(j=0;j<DD_C;j=j+1)
      begin
        if (FifoRdAddr == j)
        begin
          for (n=0;n<DW_C+1;n=n+1)
          begin
            FifoRdData[n] <= # TCo_C FifoDataBuff[j*(DW_C+1)+n];
          end
        end
      end
    end
  end

	/////////////////////////////////////////////////////////
	wire              OutMiiDataEn  = FifoRdData[DW_C    ];	//(O)output Data Enable For MII (TxEn or RxDv)
	wire  [DW_C-1:0]  OutMiiData    = FifoRdData[DW_C-1:0];	//(O)output Data For MII

//22222222222222222222222222222222222222222222222222222




//3333333333333333333333333333333333333333333333333333333
//
//	Input：
//	output：
//***************************************************/

	/////////////////////////////////////////////////////////
	reg   [1:0]   RdAddrLowReg  = 2'h0;
	reg           RdAddrChg     = 1'h0;
	reg [ACW_C:0] CurrRdAddr    = {ACW_C+1{1'h0}};

	always @( posedge InClock )  RdAddrLowReg   <= # TCo_C {RdAddrLowReg[0],FifoRdAddrCnt[0]};
	always @( posedge InClock )  RdAddrChg      <= # TCo_C (^RdAddrLowReg);
	always @( posedge InClock )  if (RdAddrChg)   CurrRdAddr  <= # TCo_C FifoRdAddrCnt;
	always @( posedge InClock )  InMiiBusy      <= # TCo_C (FifoWrAddrCnt[ACW_C    ] !=  CurrRdAddr[ACW_C    ])
	                                                     & (FifoWrAddrCnt[ACW_C-1:0] ==  CurrRdAddr[ACW_C-1:0]);


	reg   [1:0]   WrAddrLowReg  = 2'h0;
	reg           WrAddrChg     = 1'h0;
	reg [ACW_C:0] CurrWrAddr    = {ACW_C+1{1'h0}};

	always @( posedge OutClock)  WrAddrLowReg   <= # TCo_C {WrAddrLowReg[0],FifoWrAddrCnt[0]};
	always @( posedge OutClock)  WrAddrChg      <= # TCo_C (^WrAddrLowReg);
	always @( posedge OutClock)  if (WrAddrChg)   CurrWrAddr  <= # TCo_C FifoWrAddrCnt;
	always @( posedge OutClock)  OutMiiEmpty    <= # TCo_C FifoRdAddrCnt == CurrWrAddr;

//3333333333333333333333333333333333333333333333333333333

endmodule
