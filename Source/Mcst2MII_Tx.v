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

module McstTx
(
	//System Signal
	SysClk			,	//System Clock
	TxMcstClk   , //(I)Manchester Tx clock
	Reset_N     ,	//System Reset
	//MII Signal
	MiiTxCEn    , //(I)MII Tx Clock Enable
	MiiTxData   , //(I)MII Tx Data Output
	MiiTxEn     , //(I)MII Tx Enable
	MiiTxBusy   , //(O)MII Tx Busy
	//Manchester Data In/Output
	TxMcstData    //(O)Manchester Data Output
);

	/////////////////////////////////////////////////////////
	//System Signal
	input 	      SysClk    ;	//系统时钟
	input         TxMcstClk ; //(I)Manchester Tx clock
	input					Reset_N   ;	//系统复位

	/////////////////////////////////////////////////////////
	//MII Signal
	input         MiiTxCEn    ; //(I)MII Tx Clock Enable
	input   [3:0] MiiTxData   ; //(I)MII Tx Data Output
	input         MiiTxEn     ; //(I)MII Tx Enable
	output        MiiTxBusy   ; //(O)MII Tx Busy

	/////////////////////////////////////////////////////////
	//Manchester Data Output
	output  [7:0] TxMcstData  ; //(O)Manchester Data Output

	/////////////////////////////////////////////////////////


    wire NrzDataIn, TxDataAva, \TxNibbCnt[0] , \TxDataSft[1] , \TxDataSft[2] ,
        \TxDataSft[3] , \U1_TxFifo/FifoWrAddrCnt[2] , \U1_TxFifo/FifoWrAddrCnt[1] ,
        \U1_TxFifo/FifoWrSftReg[0] , \U1_TxFifo/FifoWrAddrCnt[0] , \U1_TxFifo/WrAddrSync ,
        \U1_TxFifo/FifoWrEn , \U1_TxFifo/FifoDataBuff[0] , \U1_TxFifo/FifoDataBuff[5] ,
        \U1_TxFifo/FifoDataBuff[6] , \U1_TxFifo/FifoDataBuff[7] , \U1_TxFifo/FifoDataBuff[8] ,
        \U1_TxFifo/FifoDataBuff[9] , \U1_TxFifo/FifoDataBuff[10] , \U1_TxFifo/FifoDataBuff[11] ,
        \U1_TxFifo/FifoDataBuff[12] , \U1_TxFifo/FifoDataBuff[13] , \U1_TxFifo/FifoDataBuff[14] ,
        \U1_TxFifo/FifoDataBuff[15] , \U1_TxFifo/FifoDataBuff[16] , \U1_TxFifo/FifoDataBuff[17] ,
        \U1_TxFifo/FifoDataBuff[18] , \U1_TxFifo/FifoDataBuff[19] , \U1_TxFifo/InMiiDataEnReg[0] ,
        \U1_TxFifo/FifoRdAddrCnt[0] , \TxData[0] , \U1_TxFifo/FifoDataBuff[1] ,
        \U1_TxFifo/FifoDataBuff[2] , \U1_TxFifo/FifoDataBuff[3] , \U1_TxFifo/FifoDataBuff[4] ,
        \U1_TxFifo/RdAddrChg , \U1_TxFifo/CurrRdAddr[0] , \U1_TxFifo/FifoWrData[0] ,
        \U1_TxFifo/InMiiDataEnReg[1] , \U1_TxFifo/FifoRdAddrCnt[1] , \U1_TxFifo/FifoRdAddrCnt[2] ,
        \TxData[1] , \TxData[2] , \TxData[3] , TxDataEn, \U1_TxFifo/RdAddrLowReg[0] ,
        \U1_TxFifo/RdAddrLowReg[1] , \U1_TxFifo/CurrRdAddr[1] , \U1_TxFifo/CurrRdAddr[2] ,
        \U1_TxFifo/FifoWrData[1] , \U1_TxFifo/FifoWrData[2] , \U1_TxFifo/FifoWrData[3] ,
        \U1_TxFifo/FifoWrData[4] , \U3_McsOut/NrzTxState[2] , \U3_McsOut/NrzDataEnReg[0] ,
        \U3_McsOut/NrzDataInReg , \TxNibbCnt[1] , n79, n82, n83, n85,
        n86, n88, n89, n91, n92, n94, n95, n98, n99, n104,
        n105, n106, n107, n108, n110, n113, n116, n117, n118,
        n119, n120, n121, n129, n130, \SysClk~O , n133, \TxMcstClk~O ,
        n135, n136, n137, n138, n139, n140, n141, n142;

    assign TxMcstData[7] = TxMcstData[4] /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;
    assign TxMcstData[6] = TxMcstData[4] /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;
    assign TxMcstData[5] = TxMcstData[4] /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;
    assign TxMcstData[3] = TxMcstData[0] /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;
    assign TxMcstData[2] = TxMcstData[0] /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;
    assign TxMcstData[1] = TxMcstData[0] /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;
    EFX_LUT4 LUT__207 (.I0(\TxNibbCnt[0] ), .I1(\TxNibbCnt[1] ), .O(n82)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__207.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__208 (.I0(\TxData[0] ), .I1(TxDataEn), .I2(\TxDataSft[1] ),
            .I3(n82), .O(n79)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h88f0 */ ;
    defparam LUT__208.LUTMASK = 16'h88f0;
    EFX_FF \NrzDataIn~FF  (.D(n79), .CE(1'b1), .CLK(\TxMcstClk~O ), .SR(1'b0),
           .Q(NrzDataIn)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(505)
    defparam \NrzDataIn~FF .CLK_POLARITY = 1'b1;
    defparam \NrzDataIn~FF .CE_POLARITY = 1'b1;
    defparam \NrzDataIn~FF .SR_POLARITY = 1'b1;
    defparam \NrzDataIn~FF .D_POLARITY = 1'b1;
    defparam \NrzDataIn~FF .SR_SYNC = 1'b1;
    defparam \NrzDataIn~FF .SR_VALUE = 1'b0;
    defparam \NrzDataIn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \TxDataAva~FF  (.D(TxDataEn), .CE(n82), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(TxDataAva)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(513)
    defparam \TxDataAva~FF .CLK_POLARITY = 1'b1;
    defparam \TxDataAva~FF .CE_POLARITY = 1'b1;
    defparam \TxDataAva~FF .SR_POLARITY = 1'b1;
    defparam \TxDataAva~FF .D_POLARITY = 1'b1;
    defparam \TxDataAva~FF .SR_SYNC = 1'b1;
    defparam \TxDataAva~FF .SR_VALUE = 1'b0;
    defparam \TxDataAva~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \TxNibbCnt[0]~FF  (.D(n83), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(\TxNibbCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(450)
    defparam \TxNibbCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \TxNibbCnt[0]~FF .CE_POLARITY = 1'b1;
    defparam \TxNibbCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \TxNibbCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \TxNibbCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \TxNibbCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \TxNibbCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \TxDataSft[1]~FF  (.D(n85), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\TxDataSft[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(505)
    defparam \TxDataSft[1]~FF .CLK_POLARITY = 1'b1;
    defparam \TxDataSft[1]~FF .CE_POLARITY = 1'b1;
    defparam \TxDataSft[1]~FF .SR_POLARITY = 1'b1;
    defparam \TxDataSft[1]~FF .D_POLARITY = 1'b1;
    defparam \TxDataSft[1]~FF .SR_SYNC = 1'b1;
    defparam \TxDataSft[1]~FF .SR_VALUE = 1'b0;
    defparam \TxDataSft[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \TxDataSft[2]~FF  (.D(n86), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\TxDataSft[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(505)
    defparam \TxDataSft[2]~FF .CLK_POLARITY = 1'b1;
    defparam \TxDataSft[2]~FF .CE_POLARITY = 1'b1;
    defparam \TxDataSft[2]~FF .SR_POLARITY = 1'b1;
    defparam \TxDataSft[2]~FF .D_POLARITY = 1'b1;
    defparam \TxDataSft[2]~FF .SR_SYNC = 1'b1;
    defparam \TxDataSft[2]~FF .SR_VALUE = 1'b0;
    defparam \TxDataSft[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \TxDataSft[3]~FF  (.D(\TxData[3] ), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(n88), .Q(\TxDataSft[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(505)
    defparam \TxDataSft[3]~FF .CLK_POLARITY = 1'b1;
    defparam \TxDataSft[3]~FF .CE_POLARITY = 1'b1;
    defparam \TxDataSft[3]~FF .SR_POLARITY = 1'b0;
    defparam \TxDataSft[3]~FF .D_POLARITY = 1'b1;
    defparam \TxDataSft[3]~FF .SR_SYNC = 1'b1;
    defparam \TxDataSft[3]~FF .SR_VALUE = 1'b0;
    defparam \TxDataSft[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrAddrCnt[2]~FF  (.D(n89), .CE(n91), .CLK(\SysClk~O ),
           .SR(Reset_N), .Q(\U1_TxFifo/FifoWrAddrCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(678)
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .CE_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrAddrCnt[1]~FF  (.D(n92), .CE(n91), .CLK(\SysClk~O ),
           .SR(Reset_N), .Q(\U1_TxFifo/FifoWrAddrCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(678)
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .CE_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrSftReg[0]~FF  (.D(MiiTxCEn), .CE(1'b1), .CLK(\SysClk~O ),
           .SR(1'b0), .Q(\U1_TxFifo/FifoWrSftReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(662)
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrSftReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrAddrCnt[0]~FF  (.D(n94), .CE(n91), .CLK(\SysClk~O ),
           .SR(Reset_N), .Q(\U1_TxFifo/FifoWrAddrCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(678)
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .CE_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrAddrCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/WrAddrSync~FF  (.D(n95), .CE(1'b1), .CLK(\SysClk~O ),
           .SR(1'b0), .Q(\U1_TxFifo/WrAddrSync )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(669)
    defparam \U1_TxFifo/WrAddrSync~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/WrAddrSync~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/WrAddrSync~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/WrAddrSync~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/WrAddrSync~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/WrAddrSync~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/WrAddrSync~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrEn~FF  (.D(\U1_TxFifo/FifoWrSftReg[0] ), .CE(1'b1),
           .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/FifoWrEn )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(662)
    defparam \U1_TxFifo/FifoWrEn~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrEn~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrEn~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrEn~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrEn~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrEn~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[0]~FF  (.D(\U1_TxFifo/FifoWrData[0] ),
           .CE(n98), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[5]~FF  (.D(\U1_TxFifo/FifoWrData[0] ),
           .CE(n99), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[6]~FF  (.D(\U1_TxFifo/FifoWrData[1] ),
           .CE(n99), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[7]~FF  (.D(\U1_TxFifo/FifoWrData[2] ),
           .CE(n99), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[8]~FF  (.D(\U1_TxFifo/FifoWrData[3] ),
           .CE(n99), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[8] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[9]~FF  (.D(\U1_TxFifo/FifoWrData[4] ),
           .CE(n99), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[9] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[10]~FF  (.D(\U1_TxFifo/FifoWrData[0] ),
           .CE(n104), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[10] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[11]~FF  (.D(\U1_TxFifo/FifoWrData[1] ),
           .CE(n104), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[11] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[12]~FF  (.D(\U1_TxFifo/FifoWrData[2] ),
           .CE(n104), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[12] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[13]~FF  (.D(\U1_TxFifo/FifoWrData[3] ),
           .CE(n104), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[13] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[14]~FF  (.D(\U1_TxFifo/FifoWrData[4] ),
           .CE(n104), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[14] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[15]~FF  (.D(\U1_TxFifo/FifoWrData[0] ),
           .CE(n105), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[15] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[16]~FF  (.D(\U1_TxFifo/FifoWrData[1] ),
           .CE(n105), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[16] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[17]~FF  (.D(\U1_TxFifo/FifoWrData[2] ),
           .CE(n105), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[17] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[18]~FF  (.D(\U1_TxFifo/FifoWrData[3] ),
           .CE(n105), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[18] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[18]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[19]~FF  (.D(\U1_TxFifo/FifoWrData[4] ),
           .CE(n105), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[19] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[19]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/InMiiDataEnReg[0]~FF  (.D(\U1_TxFifo/FifoWrData[4] ),
           .CE(1'b1), .CLK(\TxMcstClk~O ), .SR(1'b0), .Q(\U1_TxFifo/InMiiDataEnReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(722)
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/InMiiDataEnReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoRdAddrCnt[0]~FF  (.D(n106), .CE(n107), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(\U1_TxFifo/FifoRdAddrCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(734)
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .CE_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/dffrs_132/TxData[0]~FF  (.D(n108), .CE(n82), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\TxData[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/dffrs_132/TxData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[1]~FF  (.D(\U1_TxFifo/FifoWrData[1] ),
           .CE(n98), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[2]~FF  (.D(\U1_TxFifo/FifoWrData[2] ),
           .CE(n98), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[3]~FF  (.D(\U1_TxFifo/FifoWrData[3] ),
           .CE(n98), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoDataBuff[4]~FF  (.D(\U1_TxFifo/FifoWrData[4] ),
           .CE(n98), .CLK(\SysClk~O ), .SR(Reset_N), .Q(\U1_TxFifo/FifoDataBuff[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoDataBuff[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/RdAddrChg~FF  (.D(n110), .CE(1'b1), .CLK(\SysClk~O ),
           .SR(1'b0), .Q(\U1_TxFifo/RdAddrChg )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(781)
    defparam \U1_TxFifo/RdAddrChg~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrChg~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrChg~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrChg~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrChg~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/RdAddrChg~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/RdAddrChg~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/CurrRdAddr[0]~FF  (.D(\U1_TxFifo/FifoRdAddrCnt[0] ),
           .CE(\U1_TxFifo/RdAddrChg ), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/CurrRdAddr[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(782)
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/CurrRdAddr[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/InMiiBusy~FF  (.D(n113), .CE(1'b1), .CLK(\SysClk~O ),
           .SR(1'b0), .Q(MiiTxBusy)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(784)
    defparam \U1_TxFifo/InMiiBusy~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiBusy~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiBusy~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiBusy~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiBusy~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/InMiiBusy~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/InMiiBusy~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrData[0]~FF  (.D(MiiTxData[0]), .CE(MiiTxCEn),
           .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/FifoWrData[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_TxFifo/FifoWrData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrData[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/InMiiDataEnReg[1]~FF  (.D(\U1_TxFifo/InMiiDataEnReg[0] ),
           .CE(1'b1), .CLK(\TxMcstClk~O ), .SR(1'b0), .Q(\U1_TxFifo/InMiiDataEnReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(722)
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/InMiiDataEnReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoRdAddrCnt[1]~FF  (.D(n116), .CE(n107), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(\U1_TxFifo/FifoRdAddrCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(734)
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .CE_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoRdAddrCnt[2]~FF  (.D(n117), .CE(n107), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(\U1_TxFifo/FifoRdAddrCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(734)
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .CE_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoRdAddrCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/dffrs_132/TxData[1]~FF  (.D(n118), .CE(n82), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\TxData[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/dffrs_132/TxData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/dffrs_132/TxData[2]~FF  (.D(n119), .CE(n82), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\TxData[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/dffrs_132/TxData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/dffrs_132/TxData[3]~FF  (.D(n120), .CE(n82), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\TxData[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/dffrs_132/TxData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/dffrs_132/TxDataEn~FF  (.D(n121), .CE(n82), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(TxDataEn)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/dffrs_132/TxDataEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/RdAddrLowReg[0]~FF  (.D(\U1_TxFifo/FifoRdAddrCnt[0] ),
           .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/RdAddrLowReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(780)
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/RdAddrLowReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/RdAddrLowReg[1]~FF  (.D(\U1_TxFifo/RdAddrLowReg[0] ),
           .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/RdAddrLowReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(780)
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/RdAddrLowReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/CurrRdAddr[1]~FF  (.D(\U1_TxFifo/FifoRdAddrCnt[1] ),
           .CE(\U1_TxFifo/RdAddrChg ), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/CurrRdAddr[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(782)
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/CurrRdAddr[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/CurrRdAddr[2]~FF  (.D(\U1_TxFifo/FifoRdAddrCnt[2] ),
           .CE(\U1_TxFifo/RdAddrChg ), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/CurrRdAddr[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(782)
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/CurrRdAddr[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrData[1]~FF  (.D(MiiTxData[1]), .CE(MiiTxCEn),
           .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/FifoWrData[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_TxFifo/FifoWrData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrData[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrData[2]~FF  (.D(MiiTxData[2]), .CE(MiiTxCEn),
           .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/FifoWrData[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_TxFifo/FifoWrData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrData[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrData[3]~FF  (.D(MiiTxData[3]), .CE(MiiTxCEn),
           .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_TxFifo/FifoWrData[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_TxFifo/FifoWrData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[3]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrData[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_TxFifo/FifoWrData[4]~FF  (.D(MiiTxEn), .CE(MiiTxCEn), .CLK(\SysClk~O ),
           .SR(1'b0), .Q(\U1_TxFifo/FifoWrData[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_TxFifo/FifoWrData[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[4]~FF .CE_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[4]~FF .SR_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[4]~FF .D_POLARITY = 1'b1;
    defparam \U1_TxFifo/FifoWrData[4]~FF .SR_SYNC = 1'b1;
    defparam \U1_TxFifo/FifoWrData[4]~FF .SR_VALUE = 1'b0;
    defparam \U1_TxFifo/FifoWrData[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U3_McsOut/TxMcstDOut[0]~FF  (.D(n129), .CE(n130), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(TxMcstData[0])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(87)
    defparam \U3_McsOut/TxMcstDOut[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U3_McsOut/TxMcstDOut[0]~FF .CE_POLARITY = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[0]~FF .SR_POLARITY = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[0]~FF .D_POLARITY = 1'b1;
    defparam \U3_McsOut/TxMcstDOut[0]~FF .SR_SYNC = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[0]~FF .SR_VALUE = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U3_McsOut/NrzTxState[2]~FF  (.D(\U3_McsOut/NrzDataEnReg[0] ),
           .CE(1'b1), .CLK(\TxMcstClk~O ), .SR(1'b0), .Q(\U3_McsOut/NrzTxState[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(62)
    defparam \U3_McsOut/NrzTxState[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzTxState[2]~FF .CE_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzTxState[2]~FF .SR_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzTxState[2]~FF .D_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzTxState[2]~FF .SR_SYNC = 1'b1;
    defparam \U3_McsOut/NrzTxState[2]~FF .SR_VALUE = 1'b0;
    defparam \U3_McsOut/NrzTxState[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U3_McsOut/NrzDataEnReg[0]~FF  (.D(TxDataAva), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\U3_McsOut/NrzDataEnReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(62)
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U3_McsOut/NrzDataEnReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U3_McsOut/TxMcstDOut[1]~FF  (.D(n133), .CE(n130), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(TxMcstData[4])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(87)
    defparam \U3_McsOut/TxMcstDOut[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U3_McsOut/TxMcstDOut[1]~FF .CE_POLARITY = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[1]~FF .SR_POLARITY = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[1]~FF .D_POLARITY = 1'b1;
    defparam \U3_McsOut/TxMcstDOut[1]~FF .SR_SYNC = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[1]~FF .SR_VALUE = 1'b0;
    defparam \U3_McsOut/TxMcstDOut[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U3_McsOut/NrzDataInReg~FF  (.D(NrzDataIn), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(1'b0), .Q(\U3_McsOut/NrzDataInReg )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(61)
    defparam \U3_McsOut/NrzDataInReg~FF .CLK_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataInReg~FF .CE_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataInReg~FF .SR_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataInReg~FF .D_POLARITY = 1'b1;
    defparam \U3_McsOut/NrzDataInReg~FF .SR_SYNC = 1'b1;
    defparam \U3_McsOut/NrzDataInReg~FF .SR_VALUE = 1'b0;
    defparam \U3_McsOut/NrzDataInReg~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \TxNibbCnt[1]~FF  (.D(n135), .CE(1'b1), .CLK(\TxMcstClk~O ),
           .SR(Reset_N), .Q(\TxNibbCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(450)
    defparam \TxNibbCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \TxNibbCnt[1]~FF .CE_POLARITY = 1'b1;
    defparam \TxNibbCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \TxNibbCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \TxNibbCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \TxNibbCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \TxNibbCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_LUT4 LUT__209 (.I0(\U1_TxFifo/InMiiDataEnReg[1] ), .I1(\U1_TxFifo/InMiiDataEnReg[0] ),
            .O(n136)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4444 */ ;
    defparam LUT__209.LUTMASK = 16'h4444;
    EFX_LUT4 LUT__210 (.I0(\TxNibbCnt[0] ), .I1(n136), .O(n83)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__210.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__211 (.I0(\TxData[1] ), .I1(TxDataEn), .I2(\TxDataSft[2] ),
            .I3(n82), .O(n85)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h88f0 */ ;
    defparam LUT__211.LUTMASK = 16'h88f0;
    EFX_LUT4 LUT__212 (.I0(\TxData[2] ), .I1(TxDataEn), .I2(\TxDataSft[3] ),
            .I3(n82), .O(n86)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h88f0 */ ;
    defparam LUT__212.LUTMASK = 16'h88f0;
    EFX_LUT4 LUT__213 (.I0(TxDataEn), .I1(n82), .O(n88)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__213.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__214 (.I0(\U1_TxFifo/FifoWrAddrCnt[1] ), .I1(\U1_TxFifo/FifoWrAddrCnt[0] ),
            .I2(\U1_TxFifo/WrAddrSync ), .I3(\U1_TxFifo/FifoWrAddrCnt[2] ),
            .O(n89)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0708 */ ;
    defparam LUT__214.LUTMASK = 16'h0708;
    EFX_LUT4 LUT__215 (.I0(\U1_TxFifo/WrAddrSync ), .I1(\U1_TxFifo/FifoWrEn ),
            .O(n91)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__215.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__216 (.I0(\U1_TxFifo/WrAddrSync ), .I1(\U1_TxFifo/FifoWrAddrCnt[1] ),
            .I2(\U1_TxFifo/FifoWrAddrCnt[0] ), .O(n92)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1414 */ ;
    defparam LUT__216.LUTMASK = 16'h1414;
    EFX_LUT4 LUT__217 (.I0(\U1_TxFifo/WrAddrSync ), .I1(\U1_TxFifo/FifoWrAddrCnt[0] ),
            .O(n94)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hbbbb */ ;
    defparam LUT__217.LUTMASK = 16'hbbbb;
    EFX_LUT4 LUT__218 (.I0(\U1_TxFifo/FifoWrData[4] ), .I1(MiiTxEn), .I2(MiiTxCEn),
            .O(n95)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__218.LUTMASK = 16'h4040;
    EFX_LUT4 LUT__219 (.I0(\U1_TxFifo/FifoWrAddrCnt[1] ), .I1(\U1_TxFifo/FifoWrAddrCnt[0] ),
            .I2(\U1_TxFifo/FifoWrEn ), .O(n98)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1010 */ ;
    defparam LUT__219.LUTMASK = 16'h1010;
    EFX_LUT4 LUT__220 (.I0(\U1_TxFifo/FifoWrAddrCnt[1] ), .I1(\U1_TxFifo/FifoWrAddrCnt[0] ),
            .I2(\U1_TxFifo/FifoWrEn ), .O(n99)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__220.LUTMASK = 16'h4040;
    EFX_LUT4 LUT__221 (.I0(\U1_TxFifo/FifoWrAddrCnt[0] ), .I1(\U1_TxFifo/FifoWrAddrCnt[1] ),
            .I2(\U1_TxFifo/FifoWrEn ), .O(n104)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__221.LUTMASK = 16'h4040;
    EFX_LUT4 LUT__222 (.I0(\U1_TxFifo/FifoWrAddrCnt[1] ), .I1(\U1_TxFifo/FifoWrAddrCnt[0] ),
            .I2(\U1_TxFifo/FifoWrEn ), .O(n105)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__222.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__223 (.I0(n136), .I1(\U1_TxFifo/FifoRdAddrCnt[0] ), .O(n106)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hbbbb */ ;
    defparam LUT__223.LUTMASK = 16'hbbbb;
    EFX_LUT4 LUT__224 (.I0(n82), .I1(n136), .O(n107)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__224.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__225 (.I0(\U1_TxFifo/RdAddrLowReg[0] ), .I1(\U1_TxFifo/RdAddrLowReg[1] ),
            .O(n110)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6666 */ ;
    defparam LUT__225.LUTMASK = 16'h6666;
    EFX_LUT4 LUT__226 (.I0(\U1_TxFifo/FifoWrAddrCnt[2] ), .I1(\U1_TxFifo/FifoWrAddrCnt[0] ),
            .I2(\U1_TxFifo/CurrRdAddr[0] ), .I3(\U1_TxFifo/CurrRdAddr[2] ),
            .O(n137)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4182 */ ;
    defparam LUT__226.LUTMASK = 16'h4182;
    EFX_LUT4 LUT__227 (.I0(\U1_TxFifo/FifoWrAddrCnt[1] ), .I1(\U1_TxFifo/CurrRdAddr[1] ),
            .I2(n137), .O(n113)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h9090 */ ;
    defparam LUT__227.LUTMASK = 16'h9090;
    EFX_LUT4 LUT__228 (.I0(n136), .I1(\U1_TxFifo/FifoRdAddrCnt[1] ), .I2(\U1_TxFifo/FifoRdAddrCnt[0] ),
            .O(n116)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hbebe */ ;
    defparam LUT__228.LUTMASK = 16'hbebe;
    EFX_LUT4 LUT__229 (.I0(\U1_TxFifo/FifoRdAddrCnt[0] ), .I1(\U1_TxFifo/FifoRdAddrCnt[1] ),
            .I2(n136), .I3(\U1_TxFifo/FifoRdAddrCnt[2] ), .O(n117)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0708 */ ;
    defparam LUT__229.LUTMASK = 16'h0708;
    EFX_LUT4 LUT__230 (.I0(\U3_McsOut/NrzTxState[2] ), .I1(TxDataAva), .I2(\U3_McsOut/NrzDataInReg ),
            .I3(\U3_McsOut/NrzDataEnReg[0] ), .O(n129)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf044 */ ;
    defparam LUT__230.LUTMASK = 16'hf044;
    EFX_LUT4 LUT__231 (.I0(TxDataAva), .I1(\U3_McsOut/NrzTxState[2] ), .I2(\U3_McsOut/NrzDataEnReg[0] ),
            .O(n130)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1818 */ ;
    defparam LUT__231.LUTMASK = 16'h1818;
    EFX_LUT4 LUT__232 (.I0(\U3_McsOut/NrzDataInReg ), .I1(\U3_McsOut/NrzTxState[2] ),
            .I2(\U3_McsOut/NrzDataEnReg[0] ), .O(n133)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h5353 */ ;
    defparam LUT__232.LUTMASK = 16'h5353;
    EFX_LUT4 LUT__233 (.I0(n136), .I1(\TxNibbCnt[1] ), .I2(\TxNibbCnt[0] ),
            .O(n135)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hbebe */ ;
    defparam LUT__233.LUTMASK = 16'hbebe;
    EFX_LUT4 LUT__272 (.I0(\U1_TxFifo/FifoDataBuff[5] ), .I1(\U1_TxFifo/FifoDataBuff[15] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(\U1_TxFifo/FifoRdAddrCnt[1] ),
            .O(n138)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__272.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__273 (.I0(\U1_TxFifo/FifoDataBuff[0] ), .I1(\U1_TxFifo/FifoDataBuff[10] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(n138), .O(n108)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__273.LUTMASK = 16'hfc0a;
    EFX_GBUFCE CLKBUF__1 (.CE(1'b1), .I(SysClk), .O(\SysClk~O )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_GBUFCE, CE_POLARITY=1'b1 */ ;
    defparam CLKBUF__1.CE_POLARITY = 1'b1;
    EFX_GBUFCE CLKBUF__0 (.CE(1'b1), .I(TxMcstClk), .O(\TxMcstClk~O )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_GBUFCE, CE_POLARITY=1'b1 */ ;
    defparam CLKBUF__0.CE_POLARITY = 1'b1;
    EFX_LUT4 LUT__274 (.I0(\U1_TxFifo/FifoDataBuff[6] ), .I1(\U1_TxFifo/FifoDataBuff[16] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(\U1_TxFifo/FifoRdAddrCnt[1] ),
            .O(n139)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__274.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__275 (.I0(\U1_TxFifo/FifoDataBuff[1] ), .I1(\U1_TxFifo/FifoDataBuff[11] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(n139), .O(n118)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__275.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__276 (.I0(\U1_TxFifo/FifoDataBuff[7] ), .I1(\U1_TxFifo/FifoDataBuff[17] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(\U1_TxFifo/FifoRdAddrCnt[1] ),
            .O(n140)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__276.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__277 (.I0(\U1_TxFifo/FifoDataBuff[2] ), .I1(\U1_TxFifo/FifoDataBuff[12] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(n140), .O(n119)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__277.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__278 (.I0(\U1_TxFifo/FifoDataBuff[8] ), .I1(\U1_TxFifo/FifoDataBuff[18] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(\U1_TxFifo/FifoRdAddrCnt[1] ),
            .O(n141)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__278.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__279 (.I0(\U1_TxFifo/FifoDataBuff[3] ), .I1(\U1_TxFifo/FifoDataBuff[13] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(n141), .O(n120)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__279.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__280 (.I0(\U1_TxFifo/FifoDataBuff[9] ), .I1(\U1_TxFifo/FifoDataBuff[19] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(\U1_TxFifo/FifoRdAddrCnt[1] ),
            .O(n142)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__280.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__281 (.I0(\U1_TxFifo/FifoDataBuff[4] ), .I1(\U1_TxFifo/FifoDataBuff[14] ),
            .I2(\U1_TxFifo/FifoRdAddrCnt[0] ), .I3(n142), .O(n121)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__281.LUTMASK = 16'hfc0a;

endmodule

//
// Verific Verilog Description of module EFX_LUT40
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT41
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF0
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF1
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF2
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF3
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF4
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF5
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF6
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF7
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF8
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF9
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF10
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF11
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF12
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF13
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF14
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF15
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF16
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF17
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF18
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF19
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF20
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF21
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF22
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF23
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF24
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF25
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF26
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF27
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF28
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF29
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF30
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF31
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF32
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF33
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF34
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF35
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF36
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF37
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF38
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF39
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF40
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF41
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF42
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF43
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF44
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF45
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF46
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF47
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF48
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF49
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF50
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF51
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF52
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF53
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF54
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF55
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF56
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF57
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF58
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_FF59
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT42
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT43
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT44
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT45
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT46
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT47
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT48
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT49
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT410
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT411
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT412
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT413
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT414
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT415
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT416
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT417
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT418
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT419
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT420
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT421
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT422
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT423
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT424
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT425
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT426
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT427
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT428
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_GBUFCE0
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_GBUFCE1
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT429
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT430
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT431
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT432
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT433
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT434
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT435
// module not written out since it is a black box.
//


//
// Verific Verilog Description of module EFX_LUT436
// module not written out since it is a black box.
//
