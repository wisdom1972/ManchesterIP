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

module  McstRx
(   
	//System Signal
	SysClk      ,	//(I)System Clock
	RxMcstClk   , //(I)Manchester Rx clock
	Reset_N     ,	//(I)System Reset
	//MII Signal
	MiiRxCEn    , //(O)MII Rx Clock Enable
	MiiRxData   , //(O)MII Rx Data Input
	MiiRxDV     , //(O)MII Rx Data Valid
	MiiRxErr    , //(O)MII Rx Error
	//Manchester Signal
	RxMcstData  , //(I)Manchester Data In
	RxMcstLink  , //(O)Manchester Linked
	RxRstClk      //(O)Rx Restore Clock
);

	//Define Port
	/////////////////////////////////////////////////////////
	//System Signal
	input 				SysClk    ;	//系统时钟
	input         RxMcstClk ; //(I)Manchester Rx clock
	input					Reset_N   ; //系统复位
	
	/////////////////////////////////////////////////////////
	//MII Signal
	output        MiiRxCEn  ; //(O)MII Rx Clock Enable
	output [3:0]  MiiRxData ; //(O)MII Rx Data Input
	output        MiiRxDV   ; //(O)MII Rx Data Valid
	output        MiiRxErr  ; //(O)MII Rx Error
	
	/////////////////////////////////////////////////////////
	//Manchester Signal
	input   [ 7:0]  RxMcstData  ; //(I)Manchester Data In
	output          RxMcstLink  ; //(O)Manchester Linked
	output          RxRstClk    ; //(O)Rx Restore Clock
			

	/////////////////////////////////////////////////////////
    wire \RxNrzDAvaReg[0] , \RxClkCnt[0] , \RxDataSft[0] , RxNibbEn, 
        \RxData[0] , \RxDataAvaReg[0] , \RxClkReg[0] , RxDataAva, RxByteGen, 
        RxClkEn, InMiiFull, \LinkCnt[0] , n25, n26, \RxNrzFlagReg[0] , 
        \U2_McstDecode/PrimitData[0] , \U2_McstDecode/PrimitData[1] , \U2_McstDecode/PrimitData[2] , 
        \U2_McstDecode/PrimitData[3] , \U2_McstDecode/PrimitData[4]_2 , 
        \U2_McstDecode/PrimitData[5]_2 , \U2_McstDecode/PrimitData[6]_2 , 
        \U2_McstDecode/PrimitData[7]_2 , \U2_McstDecode/PrimitData[8]_2 , 
        \U2_McstDecode/PrimitData[9]_2 , \U2_McstDecode/PrimitData[10]_2 , 
        \U2_McstDecode/PrimitData[11]_2 , \U2_McstDecode/PrimitData[12]_2 , 
        \U2_McstDecode/PrimitData[13]_2 , \U2_McstDecode/PrimitData[14] , 
        \U2_McstDecode/PrimitData[15] , \U2_McstDecode/PrimitData[16] , 
        \U2_McstDecode/PrimitData[17] , \U2_McstDecode/U1_McstDelimit/RdDlmtPosHit , 
        \U2_McstDecode/U1_McstDelimit/RdDlmtError , \U2_McstDecode/U1_McstDelimit/RdAdjustEn , 
        \U2_McstDecode/U1_McstDelimit/RdAdjustDir , n50, n51, DmltError, 
        \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0] , \U2_McstDecode/DelimitPos[0] , 
        \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0] , n56, n57, \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0] , 
        \RxNrzDAva[0] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0] , 
        \U2_McstDecode/FPrimitData[0]_2 , \U2_McstDecode/PosAdjDir_2 , \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0] , 
        \U2_McstDecode/U1_McstDelimit/AdjustCnt[0] , \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1] , 
        \U2_McstDecode/DelimitPos[1] , \U2_McstDecode/DelimitPos[2] , \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1] , 
        \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1] , \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2] , 
        \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3] , \RxNrzDAva[1] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15] , \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16] , 
        \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17] , \U2_McstDecode/FPrimitData[1]_2 , 
        \U2_McstDecode/FPrimitData[2]_2 , \U2_McstDecode/FPrimitData[3]_2 , 
        \U2_McstDecode/FPrimitData[4]_2 , \U2_McstDecode/FPrimitData[5]_2 , 
        \U2_McstDecode/FPrimitData[6]_2 , \U2_McstDecode/FPrimitData[7]_2 , 
        \U2_McstDecode/RPrimitData[0]_2 , \U2_McstDecode/RPrimitData[1]_2 , 
        \U2_McstDecode/RPrimitData[2]_2 , \U2_McstDecode/RPrimitData[3]_2 , 
        \U2_McstDecode/RPrimitData[4]_2 , \U2_McstDecode/RPrimitData[5]_2 , 
        \U2_McstDecode/RPrimitData[6]_2 , \U2_McstDecode/RPrimitData[7]_2 , 
        \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1] , \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2] , 
        \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3] , \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4] , 
        \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5] , \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6] , 
        \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7] , \U2_McstDecode/U1_McstDelimit/AdjustCnt[1] , 
        \U2_McstDecode/U1_McstDelimit/AdjustCnt[2] , \RxNrzData[1] , \U2_McstDecode/FDecFlagStr , 
        \U2_McstDecode/FDecFlagEnd , \RxNrzData[0] , \U2_McstDecode/RDecFlagStr , 
        \U2_McstDecode/RDecFlagEnd , \U2_McstDecode/McstDataIn[24] , \U2_McstDecode/McstDataIn[23] , 
        \U2_McstDecode/McstDataIn[22] , \U2_McstDecode/McstDataIn[21] , 
        \U2_McstDecode/McstDataIn[20] , \U2_McstDecode/McstDataIn[19] , 
        \U2_McstDecode/McstDataIn[18] , \U2_McstDecode/McstDataIn[17] , 
        \U2_McstDecode/McstDataIn[16] , \U2_McstDecode/McstDataIn[15] , 
        \U2_McstDecode/McstDataIn[14] , \U2_McstDecode/McstDataIn[13] , 
        \U2_McstDecode/McstDataIn[12] , \U2_McstDecode/McstDataIn[11] , 
        \U2_McstDecode/McstDataIn[10] , \U2_McstDecode/McstDataIn[9] , \U2_McstDecode/McstDataIn[8] , 
        \U2_McstDecode/McstDataIn[7] , \U2_McstDecode/McstDataIn[6] , \U2_McstDecode/McstDataIn[5] , 
        \U2_McstDecode/McstDataIn[4] , \U2_McstDecode/McstDataIn[3] , \U2_McstDecode/McstDataIn[2] , 
        \U2_McstDecode/McstDataIn[1] , \U2_McstDecode/McstDataIn[0] , n152, 
        n153, n154, \RxNrzDAvaReg[1] , \RxClkCnt[1] , n157, n158, 
        n159, n160, \RxDataSft[1] , \RxDataSft[2] , \RxDataSft[3] , 
        \RxDataSft[4] , \RxData[1] , \RxData[2] , \RxData[3] , n168, 
        n169, \RxDataAvaReg[1] , \RxDataAvaReg[2] , \RxDataAvaReg[3] , 
        n173, n174, n175, n176, n177, \RxClkReg[1] , n179, n180, 
        \U1_ClkSmooth/ClkGen[0] , \U1_ClkSmooth/ClkDiffCnt[0] , n183, 
        n184, \U1_ClkSmooth/ClkOutEn , n187, n188, n189, n190, n191, 
        n192, n193, n194, \U1_ClkSmooth/ClkGen[1] , \U1_ClkSmooth/ClkGen[2] , 
        \U1_ClkSmooth/ClkGen[3] , \U1_ClkSmooth/ClkGen[4] , \U1_ClkSmooth/ClkGen[5] , 
        \U1_ClkSmooth/ClkGen[6] , \U1_ClkSmooth/ClkGen[7] , \U1_ClkSmooth/ClkDiffCnt[1] , 
        \U1_ClkSmooth/ClkDiffCnt[2] , \U1_ClkSmooth/ClkDiffCnt[3] , \U1_ClkSmooth/ClkDiffCnt[4] , 
        \U1_ClkSmooth/ClkDiffCnt[5] , \U1_ClkSmooth/ClkDiffCnt[6] , \U1_ClkSmooth/ClkDiffCnt[7] , 
        \U1_RxFifo/FifoWrAddrCnt[2] , \U1_RxFifo/FifoWrAddrCnt[1] , \U1_RxFifo/FifoWrSftReg[0] , 
        \U1_RxFifo/FifoWrAddrCnt[0] , \U1_RxFifo/WrAddrSync , \U1_RxFifo/FifoWrEn , 
        \U1_RxFifo/FifoDataBuff[0] , n216, n217, n218, n219, \U1_RxFifo/FifoDataBuff[5] , 
        \U1_RxFifo/FifoDataBuff[6] , \U1_RxFifo/FifoDataBuff[7] , \U1_RxFifo/FifoDataBuff[8] , 
        \U1_RxFifo/FifoDataBuff[9] , \U1_RxFifo/FifoDataBuff[10] , \U1_RxFifo/FifoDataBuff[11] , 
        \U1_RxFifo/FifoDataBuff[12] , n228, \U1_RxFifo/FifoDataBuff[13] , 
        \U1_RxFifo/FifoDataBuff[14] , \U1_RxFifo/FifoDataBuff[15] , \U1_RxFifo/FifoDataBuff[16] , 
        n233, n234, \U1_RxFifo/FifoDataBuff[17] , \U1_RxFifo/FifoDataBuff[18] , 
        \U1_RxFifo/FifoDataBuff[19] , \U1_RxFifo/InMiiDataEnReg[0] , \U1_RxFifo/FifoRdAddrCnt[0] , 
        n240, n241, n242, n243, \U1_RxFifo/FifoDataBuff[1] , \U1_RxFifo/FifoDataBuff[2] , 
        \U1_RxFifo/FifoDataBuff[3] , \U1_RxFifo/FifoDataBuff[4] , \U1_RxFifo/RdAddrChg , 
        \U1_RxFifo/CurrRdAddr[0] , n251, n252, InMiiBusy, \U1_RxFifo/WrAddrLowReg[0] , 
        \U1_RxFifo/WrAddrChg , \U1_RxFifo/CurrWrAddr[0] , n257, n258, 
        OutMiiEmpty, n260, n261, \U1_RxFifo/FifoWrData[0] , n263, 
        n264, n265, n266, n267, n268, n269, n270, n271, n272, 
        n273, n274, n275, n276, n277, n278, n279, n280, n281, 
        n282, n283, n284, n285, n286, \U1_RxFifo/InMiiDataEnReg[1] , 
        \U1_RxFifo/FifoRdAddrCnt[1] , \U1_RxFifo/FifoRdAddrCnt[2] , \U1_RxFifo/RdAddrLowReg[0] , 
        \U1_RxFifo/RdAddrLowReg[1] , \U1_RxFifo/CurrRdAddr[1] , \U1_RxFifo/CurrRdAddr[2] , 
        n298, n299, \U1_RxFifo/WrAddrLowReg[1] , \U1_RxFifo/CurrWrAddr[1] , 
        \U1_RxFifo/CurrWrAddr[2] , n303, n304, n305, n306, n307, 
        \U1_RxFifo/FifoWrData[1] , \U1_RxFifo/FifoWrData[2] , \U1_RxFifo/FifoWrData[3] , 
        \U1_RxFifo/FifoWrData[4] , \LinkCnt[1] , \LinkCnt[2] , \LinkCnt[3] , 
        \LinkCnt[4] , \LinkCnt[5] , \LinkCnt[6] , \LinkCnt[7] , \LinkCnt[8] , 
        \LinkCnt[9] , \LinkCnt[10] , \LinkCnt[11] , \LinkCnt[12] , \LinkCnt[13] , 
        \LinkCnt[14] , \LinkCnt[15] , \LinkCnt[16] , \LinkCnt[17] , 
        \LinkCnt[18] , \LinkCnt[19] , \LinkCnt[20] , \LinkCnt[21] , 
        \LinkCnt[22] , \LinkCnt[23] , \LinkCnt[24] , n336, n337, n338, 
        n339, n340, n341, n342, n343, n344, n345, n346, n347, 
        n348, n349, n350, n351, n352, n353, n354, n355, n356, 
        n357, n358, n359, n360, n361, n362, n363, n364, n365, 
        n366, n367, n368, n369, n370, n371, n372, n373, n374, 
        n375, n376, n377, n378, n379, \RxNrzFlagReg[1] , \RxNrzFlagReg[2] , 
        \RxNrzFlagReg[3] , n394, n395, n397, n398, n400, n401, 
        n405, n407, n413, n414, n415, n416, n417, n418, n419, 
        n420, n421, n422, n423, n424, n425, n426, n427, n428, 
        n429, n430, n431, n432, n443, n444, n447, n449, n451, 
        n455, n459, n460, n461, n462, n463, n464, n465, n466, 
        n478, n479, n480, n481, n482, n483, n484, n485, n486, 
        n487, n488, n489, n490, n491, n492, n493, n494, n495, 
        n496, n497, n498, n499, n500, n501, n502, n557, n562, 
        n563, n564, n565, n566, n567, n568, n571, n572, n573, 
        n574, n584, n585, n586, n587, n603, n604, n605, n606, 
        n607, n609, n610, n611, n612, n613, n614, n615, n618, 
        n623, n628, n630, n632, n633, n636, n638, n642, n644, 
        n647, n671, n672, n673, n674, n675, n676, \SysClk~O , 
        \RxMcstClk_2~O , n869, n868, n762, n763, n764, n765, n766, 
        n767, n768, n769, n770, n771, n772, n773, n774, n775, 
        n776, n777, n778, n779, n780, n781, n782, n783, n784, 
        n785, n786, n787, n788, n789, n790, n791, n792, n793, 
        n794, n795, n796, n797, n798, n799, n800, n801, n802, 
        n803, n804, n805, n806, n807, n808, n809, n810, n811, 
        n812, n813, n814, n815, n816, n817, n818, n819, n820, 
        n821, n822, n823, n824, n825, n826, n827, n828, n829, 
        n830, n831, n832, n833, n834, n835, n836, n837, n838, 
        n839, n840, n841, n842, n843, n844, n845, n846, n847, 
        n848, n849, n850, n851, n852, n853, n854, n855, n856, 
        n857, n858, n859, n860, n861, n862, n863, n864, n865, 
        n866, n867;
    
    EFX_LUT4 LUT__1150 (.I0(\LinkCnt[7] ), .I1(\LinkCnt[8] ), .I2(\LinkCnt[9] ), 
            .I3(\LinkCnt[10] ), .O(n765)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1150.LUTMASK = 16'h8000;
    EFX_FF \RxNrzDAvaReg[0]~FF  (.D(\RxNrzDAva[0] ), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxNrzDAvaReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(164)
    defparam \RxNrzDAvaReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[0]~FF .D_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[0]~FF .SR_SYNC = 1'b1;
    defparam \RxNrzDAvaReg[0]~FF .SR_VALUE = 1'b0;
    defparam \RxNrzDAvaReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxClkCnt[0]~FF  (.D(n394), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxClkCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(187)
    defparam \RxClkCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxClkCnt[0]~FF .CE_POLARITY = 1'b1;
    defparam \RxClkCnt[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxClkCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \RxClkCnt[0]~FF .SR_SYNC = 1'b1;
    defparam \RxClkCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \RxClkCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataSft[0]~FF  (.D(n395), .CE(\RxNrzDAva[0] ), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataSft[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(207)
    defparam \RxDataSft[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataSft[0]~FF .CE_POLARITY = 1'b1;
    defparam \RxDataSft[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataSft[0]~FF .D_POLARITY = 1'b1;
    defparam \RxDataSft[0]~FF .SR_SYNC = 1'b1;
    defparam \RxDataSft[0]~FF .SR_VALUE = 1'b0;
    defparam \RxDataSft[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxNibbEn~FF  (.D(n397), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(RxNibbEn)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(187)
    defparam \RxNibbEn~FF .CLK_POLARITY = 1'b1;
    defparam \RxNibbEn~FF .CE_POLARITY = 1'b1;
    defparam \RxNibbEn~FF .SR_POLARITY = 1'b1;
    defparam \RxNibbEn~FF .D_POLARITY = 1'b1;
    defparam \RxNibbEn~FF .SR_SYNC = 1'b1;
    defparam \RxNibbEn~FF .SR_VALUE = 1'b0;
    defparam \RxNibbEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxData[0]~FF  (.D(n398), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxData[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(219)
    defparam \RxData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxData[0]~FF .CE_POLARITY = 1'b1;
    defparam \RxData[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxData[0]~FF .D_POLARITY = 1'b1;
    defparam \RxData[0]~FF .SR_SYNC = 1'b1;
    defparam \RxData[0]~FF .SR_VALUE = 1'b0;
    defparam \RxData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataAvaReg[0]~FF  (.D(n400), .CE(n401), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataAvaReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(243)
    defparam \RxDataAvaReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataAvaReg[0]~FF .CE_POLARITY = 1'b0;
    defparam \RxDataAvaReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataAvaReg[0]~FF .D_POLARITY = 1'b1;
    defparam \RxDataAvaReg[0]~FF .SR_SYNC = 1'b1;
    defparam \RxDataAvaReg[0]~FF .SR_VALUE = 1'b0;
    defparam \RxDataAvaReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxClkReg[0]~FF  (.D(RxRstClk), .CE(1'b1), .CLK(\SysClk~O ), 
           .SR(1'b0), .Q(\RxClkReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(311)
    defparam \RxClkReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxClkReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \RxClkReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxClkReg[0]~FF .D_POLARITY = 1'b1;
    defparam \RxClkReg[0]~FF .SR_SYNC = 1'b1;
    defparam \RxClkReg[0]~FF .SR_VALUE = 1'b0;
    defparam \RxClkReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataAva~FF  (.D(\RxDataAvaReg[3] ), .CE(n405), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(RxDataAva)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(255)
    defparam \RxDataAva~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataAva~FF .CE_POLARITY = 1'b1;
    defparam \RxDataAva~FF .SR_POLARITY = 1'b1;
    defparam \RxDataAva~FF .D_POLARITY = 1'b1;
    defparam \RxDataAva~FF .SR_SYNC = 1'b1;
    defparam \RxDataAva~FF .SR_VALUE = 1'b0;
    defparam \RxDataAva~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxByteGen~FF  (.D(RxByteGen), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(RxByteGen)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(271)
    defparam \RxByteGen~FF .CLK_POLARITY = 1'b1;
    defparam \RxByteGen~FF .CE_POLARITY = 1'b1;
    defparam \RxByteGen~FF .SR_POLARITY = 1'b1;
    defparam \RxByteGen~FF .D_POLARITY = 1'b0;
    defparam \RxByteGen~FF .SR_SYNC = 1'b1;
    defparam \RxByteGen~FF .SR_VALUE = 1'b0;
    defparam \RxByteGen~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxClkEn~FF  (.D(n407), .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), 
           .Q(RxClkEn)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(317)
    defparam \RxClkEn~FF .CLK_POLARITY = 1'b1;
    defparam \RxClkEn~FF .CE_POLARITY = 1'b1;
    defparam \RxClkEn~FF .SR_POLARITY = 1'b1;
    defparam \RxClkEn~FF .D_POLARITY = 1'b1;
    defparam \RxClkEn~FF .SR_SYNC = 1'b1;
    defparam \RxClkEn~FF .SR_VALUE = 1'b0;
    defparam \RxClkEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \MiiRxCEn~FF  (.D(RxClkEn), .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), 
           .Q(MiiRxCEn)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(318)
    defparam \MiiRxCEn~FF .CLK_POLARITY = 1'b1;
    defparam \MiiRxCEn~FF .CE_POLARITY = 1'b1;
    defparam \MiiRxCEn~FF .SR_POLARITY = 1'b1;
    defparam \MiiRxCEn~FF .D_POLARITY = 1'b1;
    defparam \MiiRxCEn~FF .SR_SYNC = 1'b1;
    defparam \MiiRxCEn~FF .SR_VALUE = 1'b0;
    defparam \MiiRxCEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \InMiiFull~FF  (.D(InMiiBusy), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(InMiiFull)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(354)
    defparam \InMiiFull~FF .CLK_POLARITY = 1'b1;
    defparam \InMiiFull~FF .CE_POLARITY = 1'b1;
    defparam \InMiiFull~FF .SR_POLARITY = 1'b1;
    defparam \InMiiFull~FF .D_POLARITY = 1'b1;
    defparam \InMiiFull~FF .SR_SYNC = 1'b1;
    defparam \InMiiFull~FF .SR_VALUE = 1'b0;
    defparam \InMiiFull~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[0]~FF  (.D(n378), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[0]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[0]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[0]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxNrzFlagReg[0]~FF  (.D(n413), .CE(n414), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxNrzFlagReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(164)
    defparam \RxNrzFlagReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[0]~FF .D_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[0]~FF .SR_SYNC = 1'b1;
    defparam \RxNrzFlagReg[0]~FF .SR_VALUE = 1'b0;
    defparam \RxNrzFlagReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[0]~FF  (.D(n415), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[1]~FF  (.D(n416), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[2]~FF  (.D(n417), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[2]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[3]~FF  (.D(n418), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[3]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[4]~FF  (.D(n419), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[4]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[4]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[4]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[4]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[4]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[4]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[5]~FF  (.D(n420), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[5]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[5]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[5]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[5]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[5]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[5]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[6]~FF  (.D(n421), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[6]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[6]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[6]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[6]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[6]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[6]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[7]~FF  (.D(n422), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[7]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[7]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[7]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[7]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[7]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[7]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[8]~FF  (.D(n423), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[8]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[8]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[8]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[8]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[8]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[8]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[8]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[9]~FF  (.D(n424), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[9]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[9]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[9]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[9]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[9]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[9]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[9]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[10]~FF  (.D(n425), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[10]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[10]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[10]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[10]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[10]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[10]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[10]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[11]~FF  (.D(n426), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[11]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[11]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[11]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[11]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[11]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[11]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[11]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[12]~FF  (.D(n427), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[12]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[12]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[12]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[12]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[12]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[12]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[12]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[13]~FF  (.D(n428), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[13]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[13]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[13]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[13]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[13]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[13]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[13]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[14]~FF  (.D(n429), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[14] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[14]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[14]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[14]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[14]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[14]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[14]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[15]~FF  (.D(n430), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[15] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[15]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[15]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[15]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[15]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[15]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[15]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[16]~FF  (.D(n431), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[16] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[16]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[16]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[16]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[16]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[16]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[16]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/PrimitData[17]~FF  (.D(n432), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U2_McstDecode/PrimitData[17] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(385)
    defparam \U2_McstDecode/PrimitData[17]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[17]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[17]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[17]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/PrimitData[17]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/PrimitData[17]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/PrimitData[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltError~FF  (.D(n444), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(DmltError)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(623)
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltError~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF  (.D(\U2_McstDecode/U1_McstDelimit/AdjustCnt[2] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(658)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .D_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF  (.D(\U2_McstDecode/DelimitPos[0] ), 
           .CE(n447), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/DelimitPos[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(683)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .D_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF  (.D(n449), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(693)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF  (.D(\U2_McstDecode/U1_McstDelimit/DlmtPosRtn[0] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(698)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF  (.D(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\RxNrzDAva[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(707)
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .D_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF  (.D(\U2_McstDecode/PrimitData[0] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF  (.D(n455), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[0]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF  (.D(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
           .CE(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .CLK(\RxMcstClk_2~O ), 
           .SR(\U2_McstDecode/U1_McstDelimit/RdDlmtPosHit ), .Q(\U2_McstDecode/PosAdjDir_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(743)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/PosAdjDir~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF  (.D(n459), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF  (.D(n460), .CE(n461), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/AdjustCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(647)
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .CE_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF  (.D(n462), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(658)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF  (.D(n463), 
           .CE(n447), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/DelimitPos[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(683)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF  (.D(n464), 
           .CE(n465), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/DelimitPos[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(683)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .CE_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/DelimitPos[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF  (.D(n466), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(693)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF  (.D(\U2_McstDecode/U1_McstDelimit/DlmtPosRtn[1] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(698)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF  (.D(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[0] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(698)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF  (.D(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[1] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(698)
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF  (.D(\U2_McstDecode/U1_McstDelimit/DlmtPosRtnReg[3] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\RxNrzDAva[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(707)
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/RxNrzDAva[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF  (.D(\U2_McstDecode/PrimitData[1] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF  (.D(\U2_McstDecode/PrimitData[2] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF  (.D(\U2_McstDecode/PrimitData[3] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF  (.D(\U2_McstDecode/PrimitData[4]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF  (.D(\U2_McstDecode/PrimitData[5]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF  (.D(\U2_McstDecode/PrimitData[6]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF  (.D(\U2_McstDecode/PrimitData[7]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF  (.D(\U2_McstDecode/PrimitData[8]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[8] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF  (.D(\U2_McstDecode/PrimitData[9]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[9] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF  (.D(\U2_McstDecode/PrimitData[10]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[10] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF  (.D(\U2_McstDecode/PrimitData[11]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[11] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF  (.D(\U2_McstDecode/PrimitData[12]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[12] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF  (.D(\U2_McstDecode/PrimitData[13]_2 ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[13] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF  (.D(\U2_McstDecode/PrimitData[14] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[14] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF  (.D(\U2_McstDecode/PrimitData[15] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[15] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF  (.D(\U2_McstDecode/PrimitData[16] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[16] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF  (.D(\U2_McstDecode/PrimitData[17] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[17] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(720)
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/PrimitDataReg[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF  (.D(n478), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[1]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF  (.D(n479), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[2]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF  (.D(n480), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[3]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF  (.D(n481), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[4]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF  (.D(n482), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[5]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF  (.D(n483), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[6]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF  (.D(n484), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/FPrimitData[7]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/FPrimitData[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF  (.D(n485), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[0]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF  (.D(n486), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[1]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF  (.D(n487), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[2]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF  (.D(n488), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[3]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF  (.D(n489), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[4]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF  (.D(n490), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[5]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF  (.D(n491), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[6]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF  (.D(n492), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/RPrimitData[7]_2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(734)
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U2_McstDecode/RPrimitData[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF  (.D(n493), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF  (.D(n494), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF  (.D(n495), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF  (.D(n496), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF  (.D(n497), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF  (.D(n498), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF  (.D(n499), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/DmltErrCnt[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF  (.D(n500), .CE(n461), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/AdjustCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(647)
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .CE_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF  (.D(n501), .CE(n502), 
           .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U2_McstDecode/U1_McstDelimit/AdjustCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(647)
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .D_POLARITY = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/AdjustCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[24]~FF  (.D(\U2_McstDecode/McstDataIn[16] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[24] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[24]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[24]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[24]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[24]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[24]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[24]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[24]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[23]~FF  (.D(\U2_McstDecode/McstDataIn[15] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[23] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[23]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[23]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[23]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[23]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[23]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[23]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[23]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[22]~FF  (.D(\U2_McstDecode/McstDataIn[14] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[22] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[22]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[22]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[22]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[22]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[22]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[22]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[22]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[21]~FF  (.D(\U2_McstDecode/McstDataIn[13] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[21] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[21]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[21]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[21]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[21]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[21]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[21]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[21]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[20]~FF  (.D(\U2_McstDecode/McstDataIn[12] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[20] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[20]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[20]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[20]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[20]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[20]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[20]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[20]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[19]~FF  (.D(\U2_McstDecode/McstDataIn[11] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[19] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[19]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[19]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[19]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[19]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[19]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[19]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[19]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[18]~FF  (.D(\U2_McstDecode/McstDataIn[10] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[18] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[18]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[18]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[18]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[18]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[18]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[18]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[18]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[17]~FF  (.D(\U2_McstDecode/McstDataIn[9] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[17] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[17]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[17]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[17]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[17]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[17]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[17]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[16]~FF  (.D(\U2_McstDecode/McstDataIn[8] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[16] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[16]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[16]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[16]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[16]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[16]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[16]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[15]~FF  (.D(\U2_McstDecode/McstDataIn[7] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[15] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[15]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[15]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[15]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[15]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[15]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[15]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[14]~FF  (.D(\U2_McstDecode/McstDataIn[6] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[14] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[14]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[14]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[14]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[14]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[14]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[14]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[13]~FF  (.D(\U2_McstDecode/McstDataIn[5] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[13] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[13]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[13]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[13]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[13]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[13]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[13]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[12]~FF  (.D(\U2_McstDecode/McstDataIn[4] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[12] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[12]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[12]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[12]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[12]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[12]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[12]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[11]~FF  (.D(\U2_McstDecode/McstDataIn[3] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[11] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[11]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[11]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[11]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[11]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[11]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[11]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[10]~FF  (.D(\U2_McstDecode/McstDataIn[2] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[10] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[10]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[10]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[10]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[10]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[10]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[10]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[9]~FF  (.D(\U2_McstDecode/McstDataIn[1] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[9] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[9]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[9]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[9]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[9]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[9]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[9]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[8]~FF  (.D(\U2_McstDecode/McstDataIn[0] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[8] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[8]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[8]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[8]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[8]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[8]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[8]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[7]~FF  (.D(RxMcstData[0]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[7]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[7]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[7]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[7]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[7]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[6]~FF  (.D(RxMcstData[1]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[6]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[6]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[6]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[6]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[6]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[5]~FF  (.D(RxMcstData[2]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[5]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[5]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[5]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[5]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[5]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[4]~FF  (.D(RxMcstData[3]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[4]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[4]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[4]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[4]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[4]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[3]~FF  (.D(RxMcstData[4]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[3]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[3]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[3]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[3]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[3]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[2]~FF  (.D(RxMcstData[5]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[2]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[2]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[2]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[2]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[2]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[1]~FF  (.D(RxMcstData[6]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[1]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[1]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[1]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[1]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[1]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U2_McstDecode/McstDataIn[0]~FF  (.D(RxMcstData[7]), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U2_McstDecode/McstDataIn[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(353)
    defparam \U2_McstDecode/McstDataIn[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[0]~FF .CE_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[0]~FF .SR_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[0]~FF .D_POLARITY = 1'b1;
    defparam \U2_McstDecode/McstDataIn[0]~FF .SR_SYNC = 1'b1;
    defparam \U2_McstDecode/McstDataIn[0]~FF .SR_VALUE = 1'b0;
    defparam \U2_McstDecode/McstDataIn[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxNrzDAvaReg[1]~FF  (.D(\RxNrzDAva[1] ), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxNrzDAvaReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(164)
    defparam \RxNrzDAvaReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[1]~FF .D_POLARITY = 1'b1;
    defparam \RxNrzDAvaReg[1]~FF .SR_SYNC = 1'b1;
    defparam \RxNrzDAvaReg[1]~FF .SR_VALUE = 1'b0;
    defparam \RxNrzDAvaReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxClkCnt[1]~FF  (.D(n557), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxClkCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(187)
    defparam \RxClkCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxClkCnt[1]~FF .CE_POLARITY = 1'b1;
    defparam \RxClkCnt[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxClkCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \RxClkCnt[1]~FF .SR_SYNC = 1'b1;
    defparam \RxClkCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \RxClkCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataSft[1]~FF  (.D(n562), .CE(\RxNrzDAva[0] ), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataSft[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(207)
    defparam \RxDataSft[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataSft[1]~FF .CE_POLARITY = 1'b1;
    defparam \RxDataSft[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataSft[1]~FF .D_POLARITY = 1'b1;
    defparam \RxDataSft[1]~FF .SR_SYNC = 1'b1;
    defparam \RxDataSft[1]~FF .SR_VALUE = 1'b0;
    defparam \RxDataSft[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataSft[2]~FF  (.D(n563), .CE(\RxNrzDAva[0] ), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataSft[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(207)
    defparam \RxDataSft[2]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataSft[2]~FF .CE_POLARITY = 1'b1;
    defparam \RxDataSft[2]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataSft[2]~FF .D_POLARITY = 1'b1;
    defparam \RxDataSft[2]~FF .SR_SYNC = 1'b1;
    defparam \RxDataSft[2]~FF .SR_VALUE = 1'b0;
    defparam \RxDataSft[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataSft[3]~FF  (.D(n564), .CE(\RxNrzDAva[0] ), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataSft[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(207)
    defparam \RxDataSft[3]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataSft[3]~FF .CE_POLARITY = 1'b1;
    defparam \RxDataSft[3]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataSft[3]~FF .D_POLARITY = 1'b1;
    defparam \RxDataSft[3]~FF .SR_SYNC = 1'b1;
    defparam \RxDataSft[3]~FF .SR_VALUE = 1'b0;
    defparam \RxDataSft[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataSft[4]~FF  (.D(n565), .CE(\RxNrzDAva[0] ), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataSft[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(207)
    defparam \RxDataSft[4]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataSft[4]~FF .CE_POLARITY = 1'b1;
    defparam \RxDataSft[4]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataSft[4]~FF .D_POLARITY = 1'b1;
    defparam \RxDataSft[4]~FF .SR_SYNC = 1'b1;
    defparam \RxDataSft[4]~FF .SR_VALUE = 1'b0;
    defparam \RxDataSft[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxData[1]~FF  (.D(n566), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxData[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(219)
    defparam \RxData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxData[1]~FF .CE_POLARITY = 1'b1;
    defparam \RxData[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxData[1]~FF .D_POLARITY = 1'b1;
    defparam \RxData[1]~FF .SR_SYNC = 1'b1;
    defparam \RxData[1]~FF .SR_VALUE = 1'b0;
    defparam \RxData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxData[2]~FF  (.D(n567), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxData[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(219)
    defparam \RxData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \RxData[2]~FF .CE_POLARITY = 1'b1;
    defparam \RxData[2]~FF .SR_POLARITY = 1'b1;
    defparam \RxData[2]~FF .D_POLARITY = 1'b1;
    defparam \RxData[2]~FF .SR_SYNC = 1'b1;
    defparam \RxData[2]~FF .SR_VALUE = 1'b0;
    defparam \RxData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxData[3]~FF  (.D(n568), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxData[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(219)
    defparam \RxData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \RxData[3]~FF .CE_POLARITY = 1'b1;
    defparam \RxData[3]~FF .SR_POLARITY = 1'b1;
    defparam \RxData[3]~FF .D_POLARITY = 1'b1;
    defparam \RxData[3]~FF .SR_SYNC = 1'b1;
    defparam \RxData[3]~FF .SR_VALUE = 1'b0;
    defparam \RxData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataAvaReg[1]~FF  (.D(n571), .CE(n572), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataAvaReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(243)
    defparam \RxDataAvaReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataAvaReg[1]~FF .CE_POLARITY = 1'b0;
    defparam \RxDataAvaReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataAvaReg[1]~FF .D_POLARITY = 1'b1;
    defparam \RxDataAvaReg[1]~FF .SR_SYNC = 1'b1;
    defparam \RxDataAvaReg[1]~FF .SR_VALUE = 1'b0;
    defparam \RxDataAvaReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataAvaReg[2]~FF  (.D(n573), .CE(n574), .CLK(\RxMcstClk_2~O ), 
           .SR(n401), .Q(\RxDataAvaReg[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b1, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(243)
    defparam \RxDataAvaReg[2]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataAvaReg[2]~FF .CE_POLARITY = 1'b0;
    defparam \RxDataAvaReg[2]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataAvaReg[2]~FF .D_POLARITY = 1'b1;
    defparam \RxDataAvaReg[2]~FF .SR_SYNC = 1'b1;
    defparam \RxDataAvaReg[2]~FF .SR_VALUE = 1'b1;
    defparam \RxDataAvaReg[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxDataAvaReg[3]~FF  (.D(n573), .CE(n572), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxDataAvaReg[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(243)
    defparam \RxDataAvaReg[3]~FF .CLK_POLARITY = 1'b1;
    defparam \RxDataAvaReg[3]~FF .CE_POLARITY = 1'b0;
    defparam \RxDataAvaReg[3]~FF .SR_POLARITY = 1'b1;
    defparam \RxDataAvaReg[3]~FF .D_POLARITY = 1'b1;
    defparam \RxDataAvaReg[3]~FF .SR_SYNC = 1'b1;
    defparam \RxDataAvaReg[3]~FF .SR_VALUE = 1'b0;
    defparam \RxDataAvaReg[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxClkReg[1]~FF  (.D(\RxClkReg[0] ), .CE(1'b1), .CLK(\SysClk~O ), 
           .SR(1'b0), .Q(\RxClkReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(311)
    defparam \RxClkReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxClkReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \RxClkReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxClkReg[1]~FF .D_POLARITY = 1'b1;
    defparam \RxClkReg[1]~FF .SR_SYNC = 1'b1;
    defparam \RxClkReg[1]~FF .SR_VALUE = 1'b0;
    defparam \RxClkReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[0]~FF  (.D(n179), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[0]~FF  (.D(n584), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/SmthClk~FF  (.D(\U1_ClkSmooth/ClkGen[7] ), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(RxRstClk)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/SmthClk~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/SmthClk~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/SmthClk~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/SmthClk~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/SmthClk~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/SmthClk~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/SmthClk~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkOutEn~FF  (.D(n587), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkOutEn )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkOutEn~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkOutEn~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkOutEn~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkOutEn~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkOutEn~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkOutEn~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkOutEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[1]~FF  (.D(n218), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[2]~FF  (.D(n216), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[3]~FF  (.D(n193), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[3]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[3]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[4]~FF  (.D(n191), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[4]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[4]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[4]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[4]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[4]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[5]~FF  (.D(n189), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[5]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[5]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[5]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[5]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[5]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[6]~FF  (.D(n187), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[6]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[6]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[6]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[6]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[6]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkGen[7]~FF  (.D(n177), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_ClkSmooth/ClkGen[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(882)
    defparam \U1_ClkSmooth/ClkGen[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[7]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[7]~FF .SR_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[7]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[7]~FF .SR_SYNC = 1'b1;
    defparam \U1_ClkSmooth/ClkGen[7]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkGen[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[1]~FF  (.D(n603), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[2]~FF  (.D(n604), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[3]~FF  (.D(n605), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[4]~FF  (.D(n606), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[5]~FF  (.D(n607), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .D_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[6]~FF  (.D(n609), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_ClkSmooth/ClkDiffCnt[7]~FF  (.D(n610), .CE(n585), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_ClkSmooth/ClkDiffCnt[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(870)
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .CE_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .SR_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .D_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .SR_SYNC = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .SR_VALUE = 1'b0;
    defparam \U1_ClkSmooth/ClkDiffCnt[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrAddrCnt[2]~FF  (.D(n611), .CE(n612), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_RxFifo/FifoWrAddrCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(678)
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .CE_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrAddrCnt[1]~FF  (.D(n613), .CE(n612), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_RxFifo/FifoWrAddrCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(678)
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .CE_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrSftReg[0]~FF  (.D(RxNibbEn), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_RxFifo/FifoWrSftReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(662)
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrSftReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrAddrCnt[0]~FF  (.D(n614), .CE(n612), .CLK(\RxMcstClk_2~O ), 
           .SR(Reset_N), .Q(\U1_RxFifo/FifoWrAddrCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(678)
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .CE_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrAddrCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/WrAddrSync~FF  (.D(n615), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_RxFifo/WrAddrSync )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(669)
    defparam \U1_RxFifo/WrAddrSync~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrSync~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrSync~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrSync~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrSync~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/WrAddrSync~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/WrAddrSync~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrEn~FF  (.D(\U1_RxFifo/FifoWrSftReg[0] ), .CE(1'b1), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/FifoWrEn )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(662)
    defparam \U1_RxFifo/FifoWrEn~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrEn~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrEn~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrEn~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrEn~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrEn~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrEn~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[0]~FF  (.D(\U1_RxFifo/FifoWrData[0] ), 
           .CE(n618), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[5]~FF  (.D(\U1_RxFifo/FifoWrData[0] ), 
           .CE(n623), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[6]~FF  (.D(\U1_RxFifo/FifoWrData[1] ), 
           .CE(n623), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[7]~FF  (.D(\U1_RxFifo/FifoWrData[2] ), 
           .CE(n623), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[8]~FF  (.D(\U1_RxFifo/FifoWrData[3] ), 
           .CE(n623), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[8] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[9]~FF  (.D(\U1_RxFifo/FifoWrData[4] ), 
           .CE(n623), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[9] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[10]~FF  (.D(\U1_RxFifo/FifoWrData[0] ), 
           .CE(n628), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[10] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[11]~FF  (.D(\U1_RxFifo/FifoWrData[1] ), 
           .CE(n628), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[11] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[12]~FF  (.D(\U1_RxFifo/FifoWrData[2] ), 
           .CE(n628), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[12] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[13]~FF  (.D(\U1_RxFifo/FifoWrData[3] ), 
           .CE(n628), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[13] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[14]~FF  (.D(\U1_RxFifo/FifoWrData[4] ), 
           .CE(n628), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[14] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[15]~FF  (.D(\U1_RxFifo/FifoWrData[0] ), 
           .CE(n630), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[15] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[16]~FF  (.D(\U1_RxFifo/FifoWrData[1] ), 
           .CE(n630), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[16] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[17]~FF  (.D(\U1_RxFifo/FifoWrData[2] ), 
           .CE(n630), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[17] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[18]~FF  (.D(\U1_RxFifo/FifoWrData[3] ), 
           .CE(n630), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[18] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[18]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[19]~FF  (.D(\U1_RxFifo/FifoWrData[4] ), 
           .CE(n630), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[19] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[19]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/InMiiDataEnReg[0]~FF  (.D(\U1_RxFifo/FifoWrData[4] ), 
           .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/InMiiDataEnReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(722)
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/InMiiDataEnReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoRdAddrCnt[0]~FF  (.D(n632), .CE(n633), .CLK(\SysClk~O ), 
           .SR(Reset_N), .Q(\U1_RxFifo/FifoRdAddrCnt[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(734)
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .CE_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/dffrs_132/MiiRxData[0]~FF  (.D(n636), .CE(RxClkEn), 
           .CLK(\SysClk~O ), .SR(1'b0), .Q(MiiRxData[0])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[1]~FF  (.D(\U1_RxFifo/FifoWrData[1] ), 
           .CE(n618), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[2]~FF  (.D(\U1_RxFifo/FifoWrData[2] ), 
           .CE(n618), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[3]~FF  (.D(\U1_RxFifo/FifoWrData[3] ), 
           .CE(n618), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoDataBuff[4]~FF  (.D(\U1_RxFifo/FifoWrData[4] ), 
           .CE(n618), .CLK(\RxMcstClk_2~O ), .SR(Reset_N), .Q(\U1_RxFifo/FifoDataBuff[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(702)
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoDataBuff[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/RdAddrChg~FF  (.D(n638), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_RxFifo/RdAddrChg )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(781)
    defparam \U1_RxFifo/RdAddrChg~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrChg~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrChg~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrChg~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrChg~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/RdAddrChg~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/RdAddrChg~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/CurrRdAddr[0]~FF  (.D(\U1_RxFifo/FifoRdAddrCnt[0] ), 
           .CE(\U1_RxFifo/RdAddrChg ), .CLK(\RxMcstClk_2~O ), .SR(1'b0), 
           .Q(\U1_RxFifo/CurrRdAddr[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(782)
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/CurrRdAddr[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/InMiiBusy~FF  (.D(n642), .CE(1'b1), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(InMiiBusy)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(784)
    defparam \U1_RxFifo/InMiiBusy~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiBusy~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiBusy~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiBusy~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiBusy~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/InMiiBusy~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/InMiiBusy~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/WrAddrLowReg[0]~FF  (.D(\U1_RxFifo/FifoWrAddrCnt[0] ), 
           .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/WrAddrLowReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(791)
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/WrAddrLowReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/WrAddrChg~FF  (.D(n644), .CE(1'b1), .CLK(\SysClk~O ), 
           .SR(1'b0), .Q(\U1_RxFifo/WrAddrChg )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(792)
    defparam \U1_RxFifo/WrAddrChg~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrChg~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrChg~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrChg~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrChg~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/WrAddrChg~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/WrAddrChg~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/CurrWrAddr[0]~FF  (.D(\U1_RxFifo/FifoWrAddrCnt[0] ), 
           .CE(\U1_RxFifo/WrAddrChg ), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/CurrWrAddr[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(793)
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/CurrWrAddr[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/OutMiiEmpty~FF  (.D(n647), .CE(1'b1), .CLK(\SysClk~O ), 
           .SR(1'b0), .Q(OutMiiEmpty)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(794)
    defparam \U1_RxFifo/OutMiiEmpty~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/OutMiiEmpty~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/OutMiiEmpty~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/OutMiiEmpty~FF .D_POLARITY = 1'b0;
    defparam \U1_RxFifo/OutMiiEmpty~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/OutMiiEmpty~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/OutMiiEmpty~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrData[0]~FF  (.D(\RxData[0] ), .CE(RxNibbEn), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/FifoWrData[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_RxFifo/FifoWrData[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrData[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrData[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/InMiiDataEnReg[1]~FF  (.D(\U1_RxFifo/InMiiDataEnReg[0] ), 
           .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/InMiiDataEnReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(722)
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/InMiiDataEnReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoRdAddrCnt[1]~FF  (.D(n671), .CE(n633), .CLK(\SysClk~O ), 
           .SR(Reset_N), .Q(\U1_RxFifo/FifoRdAddrCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(734)
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .CE_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoRdAddrCnt[2]~FF  (.D(n672), .CE(n633), .CLK(\SysClk~O ), 
           .SR(Reset_N), .Q(\U1_RxFifo/FifoRdAddrCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(734)
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .CE_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .SR_SYNC = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoRdAddrCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/dffrs_132/MiiRxData[1]~FF  (.D(n673), .CE(RxClkEn), 
           .CLK(\SysClk~O ), .SR(1'b0), .Q(MiiRxData[1])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/dffrs_132/MiiRxData[2]~FF  (.D(n674), .CE(RxClkEn), 
           .CLK(\SysClk~O ), .SR(1'b0), .Q(MiiRxData[2])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/dffrs_132/MiiRxData[3]~FF  (.D(n675), .CE(RxClkEn), 
           .CLK(\SysClk~O ), .SR(1'b0), .Q(MiiRxData[3])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/dffrs_132/MiiRxData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/dffrs_132/MiiRxDV~FF  (.D(n676), .CE(RxClkEn), .CLK(\SysClk~O ), 
           .SR(1'b0), .Q(MiiRxDV)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(758)
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/dffrs_132/MiiRxDV~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/RdAddrLowReg[0]~FF  (.D(\U1_RxFifo/FifoRdAddrCnt[0] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/RdAddrLowReg[0] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(780)
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/RdAddrLowReg[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/RdAddrLowReg[1]~FF  (.D(\U1_RxFifo/RdAddrLowReg[0] ), 
           .CE(1'b1), .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/RdAddrLowReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(780)
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/RdAddrLowReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/CurrRdAddr[1]~FF  (.D(\U1_RxFifo/FifoRdAddrCnt[1] ), 
           .CE(\U1_RxFifo/RdAddrChg ), .CLK(\RxMcstClk_2~O ), .SR(1'b0), 
           .Q(\U1_RxFifo/CurrRdAddr[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(782)
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/CurrRdAddr[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/CurrRdAddr[2]~FF  (.D(\U1_RxFifo/FifoRdAddrCnt[2] ), 
           .CE(\U1_RxFifo/RdAddrChg ), .CLK(\RxMcstClk_2~O ), .SR(1'b0), 
           .Q(\U1_RxFifo/CurrRdAddr[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(782)
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/CurrRdAddr[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/WrAddrLowReg[1]~FF  (.D(\U1_RxFifo/WrAddrLowReg[0] ), 
           .CE(1'b1), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/WrAddrLowReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(791)
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/WrAddrLowReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/CurrWrAddr[1]~FF  (.D(\U1_RxFifo/FifoWrAddrCnt[1] ), 
           .CE(\U1_RxFifo/WrAddrChg ), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/CurrWrAddr[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(793)
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/CurrWrAddr[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/CurrWrAddr[2]~FF  (.D(\U1_RxFifo/FifoWrAddrCnt[2] ), 
           .CE(\U1_RxFifo/WrAddrChg ), .CLK(\SysClk~O ), .SR(1'b0), .Q(\U1_RxFifo/CurrWrAddr[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(793)
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/CurrWrAddr[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrData[1]~FF  (.D(\RxData[1] ), .CE(RxNibbEn), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/FifoWrData[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_RxFifo/FifoWrData[1]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[1]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[1]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[1]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[1]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrData[1]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrData[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrData[2]~FF  (.D(\RxData[2] ), .CE(RxNibbEn), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/FifoWrData[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_RxFifo/FifoWrData[2]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[2]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[2]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[2]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[2]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrData[2]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrData[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrData[3]~FF  (.D(\RxData[3] ), .CE(RxNibbEn), 
           .CLK(\RxMcstClk_2~O ), .SR(1'b0), .Q(\U1_RxFifo/FifoWrData[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_RxFifo/FifoWrData[3]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[3]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[3]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[3]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[3]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrData[3]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrData[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \U1_RxFifo/FifoWrData[4]~FF  (.D(RxDataAva), .CE(RxNibbEn), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\U1_RxFifo/FifoWrData[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(653)
    defparam \U1_RxFifo/FifoWrData[4]~FF .CLK_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[4]~FF .CE_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[4]~FF .SR_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[4]~FF .D_POLARITY = 1'b1;
    defparam \U1_RxFifo/FifoWrData[4]~FF .SR_SYNC = 1'b1;
    defparam \U1_RxFifo/FifoWrData[4]~FF .SR_VALUE = 1'b0;
    defparam \U1_RxFifo/FifoWrData[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[1]~FF  (.D(n376), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[1]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[1]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[1]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[1]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[1]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[2]~FF  (.D(n374), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[2]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[2]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[2]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[2]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[2]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[3]~FF  (.D(n372), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[3]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[3]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[3]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[3]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[3]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[3]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[4]~FF  (.D(n370), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[4] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[4]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[4]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[4]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[4]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[4]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[4]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[5]~FF  (.D(n368), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[5] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[5]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[5]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[5]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[5]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[5]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[5]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[6]~FF  (.D(n366), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[6] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[6]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[6]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[6]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[6]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[6]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[6]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[7]~FF  (.D(n364), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[7] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[7]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[7]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[7]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[7]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[7]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[7]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[8]~FF  (.D(n362), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[8] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[8]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[8]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[8]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[8]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[8]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[8]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[9]~FF  (.D(n360), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[9] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[9]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[9]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[9]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[9]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[9]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[9]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[10]~FF  (.D(n358), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[10] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[10]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[10]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[10]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[10]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[10]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[10]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[11]~FF  (.D(n356), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[11] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[11]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[11]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[11]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[11]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[11]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[11]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[12]~FF  (.D(n354), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[12] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[12]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[12]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[12]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[12]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[12]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[12]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[13]~FF  (.D(n352), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[13] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[13]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[13]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[13]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[13]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[13]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[13]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[14]~FF  (.D(n350), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[14] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[14]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[14]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[14]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[14]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[14]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[14]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[15]~FF  (.D(n348), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[15] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[15]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[15]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[15]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[15]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[15]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[15]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[16]~FF  (.D(n346), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[16] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[16]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[16]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[16]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[16]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[16]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[16]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[17]~FF  (.D(n344), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[17] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[17]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[17]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[17]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[17]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[17]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[17]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[18]~FF  (.D(n342), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[18] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[18]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[18]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[18]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[18]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[18]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[18]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[18]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[19]~FF  (.D(n340), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[19] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[19]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[19]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[19]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[19]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[19]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[19]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[19]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[20]~FF  (.D(n338), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[20] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[20]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[20]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[20]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[20]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[20]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[20]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[20]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[21]~FF  (.D(n336), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[21] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[21]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[21]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[21]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[21]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[21]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[21]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[21]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[22]~FF  (.D(n306), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[22] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[22]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[22]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[22]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[22]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[22]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[22]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[22]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[23]~FF  (.D(n304), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[23] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[23]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[23]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[23]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[23]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[23]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[23]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[23]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \LinkCnt[24]~FF  (.D(n303), .CE(1'b1), .CLK(\SysClk~O ), .SR(DmltError), 
           .Q(\LinkCnt[24] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(376)
    defparam \LinkCnt[24]~FF .CLK_POLARITY = 1'b1;
    defparam \LinkCnt[24]~FF .CE_POLARITY = 1'b1;
    defparam \LinkCnt[24]~FF .SR_POLARITY = 1'b1;
    defparam \LinkCnt[24]~FF .D_POLARITY = 1'b1;
    defparam \LinkCnt[24]~FF .SR_SYNC = 1'b1;
    defparam \LinkCnt[24]~FF .SR_VALUE = 1'b0;
    defparam \LinkCnt[24]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxNrzFlagReg[1]~FF  (.D(n762), .CE(n414), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxNrzFlagReg[1] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(164)
    defparam \RxNrzFlagReg[1]~FF .CLK_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[1]~FF .CE_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[1]~FF .SR_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[1]~FF .D_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[1]~FF .SR_SYNC = 1'b1;
    defparam \RxNrzFlagReg[1]~FF .SR_VALUE = 1'b0;
    defparam \RxNrzFlagReg[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxNrzFlagReg[2]~FF  (.D(n763), .CE(n414), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxNrzFlagReg[2] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(164)
    defparam \RxNrzFlagReg[2]~FF .CLK_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[2]~FF .CE_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[2]~FF .SR_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[2]~FF .D_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[2]~FF .SR_SYNC = 1'b1;
    defparam \RxNrzFlagReg[2]~FF .SR_VALUE = 1'b0;
    defparam \RxNrzFlagReg[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \RxNrzFlagReg[3]~FF  (.D(n764), .CE(n414), .CLK(\RxMcstClk_2~O ), 
           .SR(1'b0), .Q(\RxNrzFlagReg[3] )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b1, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(164)
    defparam \RxNrzFlagReg[3]~FF .CLK_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[3]~FF .CE_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[3]~FF .SR_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[3]~FF .D_POLARITY = 1'b1;
    defparam \RxNrzFlagReg[3]~FF .SR_SYNC = 1'b1;
    defparam \RxNrzFlagReg[3]~FF .SR_VALUE = 1'b0;
    defparam \RxNrzFlagReg[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i1  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[0] ), 
            .I1(1'b1), .CI(1'b0), .O(n25), .CO(n26)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i1 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i1  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[0] ), 
            .I1(n443), .CI(n868), .O(n50), .CO(n51)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i1 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i1  (.I0(\U1_ClkSmooth/ClkDiffCnt[0] ), .I1(n451), 
            .CI(1'b0), .O(n56), .CO(n57)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i1 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i8  (.I0(\U1_ClkSmooth/ClkDiffCnt[7] ), 
            .I1(1'b1), .CI(n154), .O(n152)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i8 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i7  (.I0(\U1_ClkSmooth/ClkDiffCnt[6] ), 
            .I1(1'b1), .CI(n158), .O(n153), .CO(n154)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i7 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i6  (.I0(\U1_ClkSmooth/ClkDiffCnt[5] ), 
            .I1(1'b1), .CI(n160), .O(n157), .CO(n158)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b0, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i6 .I0_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/sub_9/add_2/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i5  (.I0(\U1_ClkSmooth/ClkDiffCnt[4] ), 
            .I1(1'b1), .CI(n169), .O(n159), .CO(n160)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i5 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i4  (.I0(\U1_ClkSmooth/ClkDiffCnt[3] ), 
            .I1(1'b1), .CI(n174), .O(n168), .CO(n169)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i4 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i3  (.I0(\U1_ClkSmooth/ClkDiffCnt[2] ), 
            .I1(1'b1), .CI(n176), .O(n173), .CO(n174)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i3 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i2  (.I0(\U1_ClkSmooth/ClkDiffCnt[1] ), 
            .I1(1'b1), .CI(n184), .O(n175), .CO(n176)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i2 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i8  (.I0(\U1_ClkSmooth/ClkGen[7] ), .I1(\U1_ClkSmooth/ClkDiffCnt[7] ), 
            .CI(n188), .O(n177)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i8 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i1  (.I0(\U1_ClkSmooth/ClkGen[0] ), .I1(\U1_ClkSmooth/ClkDiffCnt[0] ), 
            .CI(1'b0), .O(n179), .CO(n180)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i1 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/sub_9/add_2/i1  (.I0(\U1_ClkSmooth/ClkDiffCnt[0] ), 
            .I1(n586), .CI(n869), .O(n183), .CO(n184)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(869)
    defparam \U1_ClkSmooth/sub_9/add_2/i1 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/sub_9/add_2/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i7  (.I0(\U1_ClkSmooth/ClkGen[6] ), .I1(\U1_ClkSmooth/ClkDiffCnt[6] ), 
            .CI(n190), .O(n187), .CO(n188)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i7 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i6  (.I0(\U1_ClkSmooth/ClkGen[5] ), .I1(\U1_ClkSmooth/ClkDiffCnt[5] ), 
            .CI(n192), .O(n189), .CO(n190)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i6 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i6 .I1_POLARITY = 1'b0;
    EFX_ADD \U1_ClkSmooth/add_14/i5  (.I0(\U1_ClkSmooth/ClkGen[4] ), .I1(\U1_ClkSmooth/ClkDiffCnt[4] ), 
            .CI(n194), .O(n191), .CO(n192)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i5 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i4  (.I0(\U1_ClkSmooth/ClkGen[3] ), .I1(\U1_ClkSmooth/ClkDiffCnt[3] ), 
            .CI(n217), .O(n193), .CO(n194)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i4 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i3  (.I0(\U1_ClkSmooth/ClkGen[2] ), .I1(\U1_ClkSmooth/ClkDiffCnt[2] ), 
            .CI(n219), .O(n216), .CO(n217)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i3 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_14/i2  (.I0(\U1_ClkSmooth/ClkGen[1] ), .I1(\U1_ClkSmooth/ClkDiffCnt[1] ), 
            .CI(n180), .O(n218), .CO(n219)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(879)
    defparam \U1_ClkSmooth/add_14/i2 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_14/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i8  (.I0(\U1_ClkSmooth/ClkDiffCnt[7] ), .I1(1'b0), 
            .CI(n234), .O(n228)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i8 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i7  (.I0(\U1_ClkSmooth/ClkDiffCnt[6] ), .I1(1'b0), 
            .CI(n241), .O(n233), .CO(n234)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i7 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i6  (.I0(\U1_ClkSmooth/ClkDiffCnt[5] ), .I1(1'b0), 
            .CI(n243), .O(n240), .CO(n241)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b0, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i6 .I0_POLARITY = 1'b0;
    defparam \U1_ClkSmooth/add_7/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i5  (.I0(\U1_ClkSmooth/ClkDiffCnt[4] ), .I1(1'b0), 
            .CI(n252), .O(n242), .CO(n243)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i5 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i4  (.I0(\U1_ClkSmooth/ClkDiffCnt[3] ), .I1(1'b0), 
            .CI(n258), .O(n251), .CO(n252)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i4 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i3  (.I0(\U1_ClkSmooth/ClkDiffCnt[2] ), .I1(1'b0), 
            .CI(n261), .O(n257), .CO(n258)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i3 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \U1_ClkSmooth/add_7/i2  (.I0(\U1_ClkSmooth/ClkDiffCnt[1] ), .I1(1'b0), 
            .CI(n57), .O(n260), .CO(n261)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(868)
    defparam \U1_ClkSmooth/add_7/i2 .I0_POLARITY = 1'b1;
    defparam \U1_ClkSmooth/add_7/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i8  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[7] ), 
            .I1(1'b1), .CI(n265), .O(n263)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i8 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i7  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[6] ), 
            .I1(1'b1), .CI(n267), .O(n264), .CO(n265)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i7 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i6  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[5] ), 
            .I1(1'b1), .CI(n269), .O(n266), .CO(n267)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i6 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i5  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[4] ), 
            .I1(1'b1), .CI(n271), .O(n268), .CO(n269)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i5 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i4  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[3] ), 
            .I1(1'b1), .CI(n273), .O(n270), .CO(n271)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i4 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i3  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[2] ), 
            .I1(1'b1), .CI(n275), .O(n272), .CO(n273)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i3 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i2  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[1] ), 
            .I1(1'b1), .CI(n51), .O(n274), .CO(n275)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(620)
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i2 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/sub_7/add_2/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i8  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[7] ), 
            .I1(1'b0), .CI(n278), .O(n276)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i8 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i7  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[6] ), 
            .I1(1'b0), .CI(n280), .O(n277), .CO(n278)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i7 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i6  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[5] ), 
            .I1(1'b0), .CI(n282), .O(n279), .CO(n280)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i6 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i5  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[4] ), 
            .I1(1'b0), .CI(n284), .O(n281), .CO(n282)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i5 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i4  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[3] ), 
            .I1(1'b1), .CI(n286), .O(n283), .CO(n284)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i4 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i3  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[2] ), 
            .I1(1'b1), .CI(n299), .O(n285), .CO(n286)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i3 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \U2_McstDecode/U1_McstDelimit/add_5/i2  (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[1] ), 
            .I1(1'b1), .CI(n26), .O(n298), .CO(n299)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(619)
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i2 .I0_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/add_5/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i25  (.I0(\LinkCnt[24] ), .I1(1'b0), .CI(n305), .O(n303)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i25 .I0_POLARITY = 1'b1;
    defparam \add_56/i25 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i24  (.I0(\LinkCnt[23] ), .I1(1'b0), .CI(n307), .O(n304), 
            .CO(n305)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i24 .I0_POLARITY = 1'b1;
    defparam \add_56/i24 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i23  (.I0(\LinkCnt[22] ), .I1(1'b0), .CI(n337), .O(n306), 
            .CO(n307)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i23 .I0_POLARITY = 1'b1;
    defparam \add_56/i23 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i22  (.I0(\LinkCnt[21] ), .I1(1'b0), .CI(n339), .O(n336), 
            .CO(n337)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i22 .I0_POLARITY = 1'b1;
    defparam \add_56/i22 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i21  (.I0(\LinkCnt[20] ), .I1(1'b0), .CI(n341), .O(n338), 
            .CO(n339)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i21 .I0_POLARITY = 1'b1;
    defparam \add_56/i21 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i20  (.I0(\LinkCnt[19] ), .I1(1'b0), .CI(n343), .O(n340), 
            .CO(n341)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i20 .I0_POLARITY = 1'b1;
    defparam \add_56/i20 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i19  (.I0(\LinkCnt[18] ), .I1(1'b0), .CI(n345), .O(n342), 
            .CO(n343)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i19 .I0_POLARITY = 1'b1;
    defparam \add_56/i19 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i18  (.I0(\LinkCnt[17] ), .I1(1'b0), .CI(n347), .O(n344), 
            .CO(n345)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i18 .I0_POLARITY = 1'b1;
    defparam \add_56/i18 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i17  (.I0(\LinkCnt[16] ), .I1(1'b0), .CI(n349), .O(n346), 
            .CO(n347)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i17 .I0_POLARITY = 1'b1;
    defparam \add_56/i17 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i16  (.I0(\LinkCnt[15] ), .I1(1'b0), .CI(n351), .O(n348), 
            .CO(n349)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i16 .I0_POLARITY = 1'b1;
    defparam \add_56/i16 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i15  (.I0(\LinkCnt[14] ), .I1(1'b0), .CI(n353), .O(n350), 
            .CO(n351)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i15 .I0_POLARITY = 1'b1;
    defparam \add_56/i15 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i14  (.I0(\LinkCnt[13] ), .I1(1'b0), .CI(n355), .O(n352), 
            .CO(n353)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i14 .I0_POLARITY = 1'b1;
    defparam \add_56/i14 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i13  (.I0(\LinkCnt[12] ), .I1(1'b0), .CI(n357), .O(n354), 
            .CO(n355)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i13 .I0_POLARITY = 1'b1;
    defparam \add_56/i13 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i12  (.I0(\LinkCnt[11] ), .I1(1'b0), .CI(n359), .O(n356), 
            .CO(n357)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i12 .I0_POLARITY = 1'b1;
    defparam \add_56/i12 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i11  (.I0(\LinkCnt[10] ), .I1(1'b0), .CI(n361), .O(n358), 
            .CO(n359)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i11 .I0_POLARITY = 1'b1;
    defparam \add_56/i11 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i10  (.I0(\LinkCnt[9] ), .I1(1'b0), .CI(n363), .O(n360), 
            .CO(n361)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i10 .I0_POLARITY = 1'b1;
    defparam \add_56/i10 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i9  (.I0(\LinkCnt[8] ), .I1(1'b0), .CI(n365), .O(n362), 
            .CO(n363)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i9 .I0_POLARITY = 1'b1;
    defparam \add_56/i9 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i8  (.I0(\LinkCnt[7] ), .I1(1'b0), .CI(n367), .O(n364), 
            .CO(n365)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i8 .I0_POLARITY = 1'b1;
    defparam \add_56/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i7  (.I0(\LinkCnt[6] ), .I1(1'b0), .CI(n369), .O(n366), 
            .CO(n367)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i7 .I0_POLARITY = 1'b1;
    defparam \add_56/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i6  (.I0(\LinkCnt[5] ), .I1(1'b0), .CI(n371), .O(n368), 
            .CO(n369)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i6 .I0_POLARITY = 1'b1;
    defparam \add_56/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i5  (.I0(\LinkCnt[4] ), .I1(1'b0), .CI(n373), .O(n370), 
            .CO(n371)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i5 .I0_POLARITY = 1'b1;
    defparam \add_56/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i4  (.I0(\LinkCnt[3] ), .I1(1'b0), .CI(n375), .O(n372), 
            .CO(n373)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i4 .I0_POLARITY = 1'b1;
    defparam \add_56/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i3  (.I0(\LinkCnt[2] ), .I1(1'b0), .CI(n377), .O(n374), 
            .CO(n375)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i3 .I0_POLARITY = 1'b1;
    defparam \add_56/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i2  (.I0(\LinkCnt[1] ), .I1(1'b0), .CI(n379), .O(n376), 
            .CO(n377)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i2 .I0_POLARITY = 1'b1;
    defparam \add_56/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \add_56/i1  (.I0(\LinkCnt[0] ), .I1(RxMcstLink), .CI(1'b0), 
            .O(n378), .CO(n379)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b0 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/McstRx2Mii.v(375)
    defparam \add_56/i1 .I0_POLARITY = 1'b1;
    defparam \add_56/i1 .I1_POLARITY = 1'b0;
    EFX_RAM_5K \U2_McstDecode/U1_McstDelimit/U1_DlmtRom  (.WCLK(1'b0), .WE(1'b0), 
            .WCLKE(1'b0), .RCLK(\RxMcstClk_2~O ), .RE(1'b1), .WADDR({10'b0000000000}), 
            .RADDR({\U2_McstDecode/PrimitData[12]_2 , \U2_McstDecode/PrimitData[11]_2 , 
            \U2_McstDecode/PrimitData[10]_2 , \U2_McstDecode/PrimitData[9]_2 , 
            \U2_McstDecode/PrimitData[8]_2 , \U2_McstDecode/PrimitData[7]_2 , 
            \U2_McstDecode/PrimitData[6]_2 , \U2_McstDecode/PrimitData[5]_2 , 
            \U2_McstDecode/PrimitData[4]_2 , \U2_McstDecode/PrimitData[13]_2 }), 
            .RDATA({Open_0, \U2_McstDecode/U1_McstDelimit/RdDlmtPosHit , 
            \U2_McstDecode/U1_McstDelimit/RdDlmtError , \U2_McstDecode/U1_McstDelimit/RdAdjustEn , 
            \U2_McstDecode/U1_McstDelimit/RdAdjustDir })) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_RAM_5K, EFX_ATTRIBUTE_INSTANCE__IS_STF_RAM_5K=TRUE, WRITE_WIDTH=5, READ_WIDTH=5, WCLK_POLARITY=1'b1, WCLKE_POLARITY=1'b1, WE_POLARITY=1'b1, RCLK_POLARITY=1'b1, RE_POLARITY=1'b1, OUTPUT_REG=1'b0, WRITE_MODE="READ_FIRST", INIT_0=256'b0010000100001000000110011100000000000100000000000000010000010000100001000010010000000000000001000001100111000000000000000000000000000000000110001100011000110100000000000000010000011000110001100011010000000000000001000001000010000100001001000000000000000100, INIT_1=256'b0000000000000000000000010000100001000011000100001000010000100001000010000001100111000000000001000000000000000100000110001100011000110100000000000000010000010000100001000010010000000000000001000100001100010000100001000010000100001000010000110001000010000100, INIT_2=256'b0000000000011000110001100011010000000000000001000001100011000110001101000000000000000100000100001000010000100100000000000000010000010001100000000000000100001000010000100001000110000000000000010001100001000110000100011000000000000001000110000100011000000000, INIT_3=256'b1000010000100001000010000100001000010000100001000010000100001000000100011000000000000001000010000100001000010001100000000000000100011000010001100100001100010000100001000000000000000100000100001000010000100100000000000000010000011001110000000000000000000000, INIT_4=256'b0001000010000000000000010000100001000010000100001000000000000100001000010000100000010000100000000000010000100001000010000001100011000110001100000000000011100111000100001000000000000001000010000100001000010000100000000000000000000000111001110100001000010000, INIT_5=256'b0010000100001000000110011100000000000100000000000000010000010000100001000010010000000000000001000001100111000000000000000000000000000000000110001100011000110100000000000000010000011000110001100011010000000000000001000001000010000100001001000000000000000100, INIT_6=256'b1100011000110000000000001110011100010001100000000000000100001000010000100100001100010000100001000000000000000100000110001100011000110100000000000000010000010000100001000010010000000000000001000100001100010000100001000010000100001000010000110001000010000100, INIT_7=256'b0000000000010000100001000010000000000000000000000001000010000100001000000000000000000000000100001000010000100000000000000000000000010000100000000000000100001000010000100001000010000000000001000010000100001000000100001000000000000100001000010000100000011000, INIT_8=256'b1000010000100001000010000100001000010000100001000010000100001000000110001100000000000100001000010000100000011000110000000000000110001100011000110001100011000000000000000000000001100011010000100001000010000100001000010000100001000010000000000000000000000000, INIT_9=256'b0000000000000000000001000010000100001000000110001100000000000001100011000110001100011000110000000000000110001100011000110001100011000110001100000000000001100011000110001100000000000100001000010000100000011000110000000000000000000000011000110100001000010000, INIT_A=256'b0010000100001000000110001100000000000000000000000000000001000010000100001000000000000000000000000001100011000000000000000000000000000000000110001100011000110000000000000000000000011000110001100011000000000000000000000100001000010000100000000000000000000000, INIT_B=256'b0000000000000000000000010000100001000010000100001000010000100001000010000001100011000000000000000000000000000000000110001100011000110000000000000000000001000010000100001000000000000000000000000100001000010000100001000010000100001000010000100001000010000100, INIT_C=256'b0000000001000010000100001000000000000000010000100100001000010000100000000000000001000010000000000000000000000000000000000100001000000000000000000000000000000000000000000000000000000000000000010000100001000010000000000000000000000001000010000100001000000000, INIT_D=256'b1000010000100001100010000100001000010000100001000010000110001000001000000000000010000000000000000000000000100000000000001000000110001100011000110010000000000000100001000010000110001000000000000000000000000000000000001100001000111001110000000000000000000000, INIT_E=256'b0010000000000000100000000000000000000000001000000000000010000001100011000110001100100000000000001000000110001100011000110000000000000000000000000000000011100011001000000000000010000000000000000000000000100000000000001000000000000000111000110100001000010000, INIT_F=256'b0010000100001000001110011100000000000000000000000100001000000000000000000000000000000000010000100011100111000000000000000000000000000000010000100001000010000000000000000100001001000010000100001000000000000000010000100000000000000000000000000000000001000010, INIT_10=256'b0000000000000000000000001110001100100000000000001000000000000000000000000010000000000000100001000010000110001000001100001000110000100000000000001100001000000000000000000000000000000000110000100100001000010000100001000010000100001000010000100001000010000100, INIT_11=256'b0000000000110000100011000010000000000000110000100011000010001100001000000000000011000010000000000000000000000000000000001100001000100000000000001000000000000000000000000010000000000000100000011000110001100011001000000000000010000001100011000110001100000000, INIT_12=256'b1000010000100001100010000100001000010000100001000010000110001000001000000000000010000000000000000000000000100000000000001000000110001100011000110010000000000000100000000000000011100011010000100001000010000100001000011000100001000010000000000000000000000000, INIT_13=256'b0010000000000000100000000000000000000000001000000000000010000001100011000110001100100000000000001000000110001100011000110000000000000000000000000000000011100011001000000000000010000000000000000000000000100000000000001000000000000000111000110100001000010000 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(582)
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .READ_WIDTH = 5;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .WRITE_WIDTH = 5;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .WCLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .WCLKE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .WE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .RCLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .RE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_0 = 256'b0010000100001000000110011100000000000100000000000000010000010000100001000010010000000000000001000001100111000000000000000000000000000000000110001100011000110100000000000000010000011000110001100011010000000000000001000001000010000100001001000000000000000100;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_1 = 256'b0000000000000000000000010000100001000011000100001000010000100001000010000001100111000000000001000000000000000100000110001100011000110100000000000000010000010000100001000010010000000000000001000100001100010000100001000010000100001000010000110001000010000100;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_2 = 256'b0000000000011000110001100011010000000000000001000001100011000110001101000000000000000100000100001000010000100100000000000000010000010001100000000000000100001000010000100001000110000000000000010001100001000110000100011000000000000001000110000100011000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_3 = 256'b1000010000100001000010000100001000010000100001000010000100001000000100011000000000000001000010000100001000010001100000000000000100011000010001100100001100010000100001000000000000000100000100001000010000100100000000000000010000011001110000000000000000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_4 = 256'b0001000010000000000000010000100001000010000100001000000000000100001000010000100000010000100000000000010000100001000010000001100011000110001100000000000011100111000100001000000000000001000010000100001000010000100000000000000000000000111001110100001000010000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_5 = 256'b0010000100001000000110011100000000000100000000000000010000010000100001000010010000000000000001000001100111000000000000000000000000000000000110001100011000110100000000000000010000011000110001100011010000000000000001000001000010000100001001000000000000000100;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_6 = 256'b1100011000110000000000001110011100010001100000000000000100001000010000100100001100010000100001000000000000000100000110001100011000110100000000000000010000010000100001000010010000000000000001000100001100010000100001000010000100001000010000110001000010000100;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_7 = 256'b0000000000010000100001000010000000000000000000000001000010000100001000000000000000000000000100001000010000100000000000000000000000010000100000000000000100001000010000100001000010000000000001000010000100001000000100001000000000000100001000010000100000011000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_8 = 256'b1000010000100001000010000100001000010000100001000010000100001000000110001100000000000100001000010000100000011000110000000000000110001100011000110001100011000000000000000000000001100011010000100001000010000100001000010000100001000010000000000000000000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_9 = 256'b0000000000000000000001000010000100001000000110001100000000000001100011000110001100011000110000000000000110001100011000110001100011000110001100000000000001100011000110001100000000000100001000010000100000011000110000000000000000000000011000110100001000010000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_A = 256'b0010000100001000000110001100000000000000000000000000000001000010000100001000000000000000000000000001100011000000000000000000000000000000000110001100011000110000000000000000000000011000110001100011000000000000000000000100001000010000100000000000000000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_B = 256'b0000000000000000000000010000100001000010000100001000010000100001000010000001100011000000000000000000000000000000000110001100011000110000000000000000000001000010000100001000000000000000000000000100001000010000100001000010000100001000010000100001000010000100;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_C = 256'b0000000001000010000100001000000000000000010000100100001000010000100000000000000001000010000000000000000000000000000000000100001000000000000000000000000000000000000000000000000000000000000000010000100001000010000000000000000000000001000010000100001000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_D = 256'b1000010000100001100010000100001000010000100001000010000110001000001000000000000010000000000000000000000000100000000000001000000110001100011000110010000000000000100001000010000110001000000000000000000000000000000000001100001000111001110000000000000000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_E = 256'b0010000000000000100000000000000000000000001000000000000010000001100011000110001100100000000000001000000110001100011000110000000000000000000000000000000011100011001000000000000010000000000000000000000000100000000000001000000000000000111000110100001000010000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_F = 256'b0010000100001000001110011100000000000000000000000100001000000000000000000000000000000000010000100011100111000000000000000000000000000000010000100001000010000000000000000100001001000010000100001000000000000000010000100000000000000000000000000000000001000010;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_10 = 256'b0000000000000000000000001110001100100000000000001000000000000000000000000010000000000000100001000010000110001000001100001000110000100000000000001100001000000000000000000000000000000000110000100100001000010000100001000010000100001000010000100001000010000100;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_11 = 256'b0000000000110000100011000010000000000000110000100011000010001100001000000000000011000010000000000000000000000000000000001100001000100000000000001000000000000000000000000010000000000000100000011000110001100011001000000000000010000001100011000110001100000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_12 = 256'b1000010000100001100010000100001000010000100001000010000110001000001000000000000010000000000000000000000000100000000000001000000110001100011000110010000000000000100000000000000011100011010000100001000010000100001000011000100001000010000000000000000000000000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .INIT_13 = 256'b0010000000000000100000000000000000000000001000000000000010000001100011000110001100100000000000001000000110001100011000110000000000000000000000000000000011100011001000000000000010000000000000000000000000100000000000001000000000000000111000110100001000010000;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .OUTPUT_REG = 1'b0;
    defparam \U2_McstDecode/U1_McstDelimit/U1_DlmtRom .WRITE_MODE = "READ_FIRST";
    EFX_RAM_5K \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode  (.WCLK(1'b0), 
            .WE(1'b0), .WCLKE(1'b0), .RCLK(\RxMcstClk_2~O ), .RE(1'b1), 
            .WADDR({9'b000000000}), .RADDR({\U2_McstDecode/FPrimitData[7]_2 , 
            \U2_McstDecode/FPrimitData[6]_2 , \U2_McstDecode/FPrimitData[5]_2 , 
            \U2_McstDecode/FPrimitData[4]_2 , \U2_McstDecode/FPrimitData[3]_2 , 
            \U2_McstDecode/FPrimitData[2]_2 , \U2_McstDecode/FPrimitData[1]_2 , 
            \U2_McstDecode/FPrimitData[0]_2 , \U2_McstDecode/PosAdjDir_2 }), 
            .RDATA({Open_1, Open_2, Open_3, Open_4, Open_5, Open_6, 
            \U2_McstDecode/FDecFlagStr , \U2_McstDecode/FDecFlagEnd , \RxNrzData[1] , 
            Open_7})) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_RAM_5K, EFX_ATTRIBUTE_INSTANCE__IS_STF_RAM_5K=TRUE, WRITE_WIDTH=10, READ_WIDTH=10, WCLK_POLARITY=1'b1, WCLKE_POLARITY=1'b1, WE_POLARITY=1'b1, RCLK_POLARITY=1'b1, RE_POLARITY=1'b1, OUTPUT_REG=1'b0, WRITE_MODE="READ_FIRST", INIT_0=256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100, INIT_1=256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010, INIT_2=256'b0101000100010100010001010001000000010000000001000001010001000101000100000001000000000100000101010000010101000000000100000000010000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000, INIT_3=256'b0010001000001000100000100010000010001000001000100000100010000010000110000100011000010001100001000110000100011000010001100001000110000100011000010010000001001000000100000001000000000100000101010000010101000000000100000000010000010100010001010001000101000100, INIT_4=256'b0001100001000110000100011000010001100001000110000100011000010000000010000000000100011000010001100001000000001000000000010001010010000101001000010100100001010010000110000100011000010001100001000110000100011000010001100001000101001000010100100010000010001000, INIT_5=256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100, INIT_6=256'b1000010100100001010010000101001000011000010001100001000110000100011000010010000001001000000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010, INIT_7=256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100000000100000000001000110000100011000010000000010000000000100010100, INIT_8=256'b0010001000001000100000100010000010001000001000100000100010000010000110101100011010110000000100000000010000011010110001101011000101001000010100100001101011000110101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000, INIT_9=256'b0001101011000110101100000001000000000100000110101100011010110001010010000101001000011010110001101011000101001000010100100001010010000101001000010100100001010010000110101100011010110000000100000000010000011010110001101011000101001000010100100010000010001000, INIT_A=256'b0000010010000001000101000100010100010001100100000110010000000001000000000100000110010000011001000001010001000101000100010100010001010001000101000100010100010001100100000110010000010100010001010001000110010000011001000000000100000000010000011001000001100100, INIT_B=256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100011001000001100100000101000100010100010001100100000110010000000001000000000100000110010000011001000010000001001000000100100000010010000001001000000100100000010010, INIT_C=256'b0101000100000000010000000010000110001000011000100000000001000000001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000, INIT_D=256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100100000100010000010000110001000011000100001100010000110001000010100010001010001000101000100, INIT_E=256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000, INIT_F=256'b0000010010000001000101000100010100010001100010000110001000011000100001100010000110001000011000100001010001000101000100010100010001010001000000000100000000100001100010000110001000000000010000000010000110001000011000100001100010000110001000011000100001100010, INIT_10=256'b1000010100100001010010000101001000000010110000001011000101101100010110110000001011000000101100100000100010000010000110001000011000100001100010000110001000011000100001100010000110001000011000100010000001001000000100100000010010000001001000000100100000010010, INIT_11=256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000000010110000001011000101101100010110110000001011000000101100010100100001010010000000101100000010110001010010000101001000010100, INIT_12=256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000, INIT_13=256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(863)
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .READ_WIDTH = 10;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .WRITE_WIDTH = 10;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .WCLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .WCLKE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .WE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .RCLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .RE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_0 = 256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_1 = 256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_2 = 256'b0101000100010100010001010001000000010000000001000001010001000101000100000001000000000100000101010000010101000000000100000000010000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_3 = 256'b0010001000001000100000100010000010001000001000100000100010000010000110000100011000010001100001000110000100011000010001100001000110000100011000010010000001001000000100000001000000000100000101010000010101000000000100000000010000010100010001010001000101000100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_4 = 256'b0001100001000110000100011000010001100001000110000100011000010000000010000000000100011000010001100001000000001000000000010001010010000101001000010100100001010010000110000100011000010001100001000110000100011000010001100001000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_5 = 256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_6 = 256'b1000010100100001010010000101001000011000010001100001000110000100011000010010000001001000000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_7 = 256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100000000100000000001000110000100011000010000000010000000000100010100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_8 = 256'b0010001000001000100000100010000010001000001000100000100010000010000110101100011010110000000100000000010000011010110001101011000101001000010100100001101011000110101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_9 = 256'b0001101011000110101100000001000000000100000110101100011010110001010010000101001000011010110001101011000101001000010100100001010010000101001000010100100001010010000110101100011010110000000100000000010000011010110001101011000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_A = 256'b0000010010000001000101000100010100010001100100000110010000000001000000000100000110010000011001000001010001000101000100010100010001010001000101000100010100010001100100000110010000010100010001010001000110010000011001000000000100000000010000011001000001100100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_B = 256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100011001000001100100000101000100010100010001100100000110010000000001000000000100000110010000011001000010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_C = 256'b0101000100000000010000000010000110001000011000100000000001000000001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_D = 256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100100000100010000010000110001000011000100001100010000110001000010100010001010001000101000100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_E = 256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_F = 256'b0000010010000001000101000100010100010001100010000110001000011000100001100010000110001000011000100001010001000101000100010100010001010001000000000100000000100001100010000110001000000000010000000010000110001000011000100001100010000110001000011000100001100010;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_10 = 256'b1000010100100001010010000101001000000010110000001011000101101100010110110000001011000000101100100000100010000010000110001000011000100001100010000110001000011000100001100010000110001000011000100010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_11 = 256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000000010110000001011000101101100010110110000001011000000101100010100100001010010000000101100000010110001010010000101001000010100;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_12 = 256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .INIT_13 = 256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .OUTPUT_REG = 1'b0;
    defparam \U2_McstDecode/U3_FrontMcstDecRom/U2_McstDecode .WRITE_MODE = "READ_FIRST";
    EFX_RAM_5K \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode  (.WCLK(1'b0), 
            .WE(1'b0), .WCLKE(1'b0), .RCLK(\RxMcstClk_2~O ), .RE(1'b1), 
            .WADDR({9'b000000000}), .RADDR({\U2_McstDecode/RPrimitData[7]_2 , 
            \U2_McstDecode/RPrimitData[6]_2 , \U2_McstDecode/RPrimitData[5]_2 , 
            \U2_McstDecode/RPrimitData[4]_2 , \U2_McstDecode/RPrimitData[3]_2 , 
            \U2_McstDecode/RPrimitData[2]_2 , \U2_McstDecode/RPrimitData[1]_2 , 
            \U2_McstDecode/RPrimitData[0]_2 , \U2_McstDecode/PosAdjDir_2 }), 
            .RDATA({Open_8, Open_9, Open_10, Open_11, Open_12, Open_13, 
            \U2_McstDecode/RDecFlagStr , \U2_McstDecode/RDecFlagEnd , \RxNrzData[0] , 
            Open_14})) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_RAM_5K, EFX_ATTRIBUTE_INSTANCE__IS_STF_RAM_5K=TRUE, WRITE_WIDTH=10, READ_WIDTH=10, WCLK_POLARITY=1'b1, WCLKE_POLARITY=1'b1, WE_POLARITY=1'b1, RCLK_POLARITY=1'b1, RE_POLARITY=1'b1, OUTPUT_REG=1'b0, WRITE_MODE="READ_FIRST", INIT_0=256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100, INIT_1=256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010, INIT_2=256'b0101000100010100010001010001000000010000000001000001010001000101000100000001000000000100000101010000010101000000000100000000010000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000, INIT_3=256'b0010001000001000100000100010000010001000001000100000100010000010000110000100011000010001100001000110000100011000010001100001000110000100011000010010000001001000000100000001000000000100000101010000010101000000000100000000010000010100010001010001000101000100, INIT_4=256'b0001100001000110000100011000010001100001000110000100011000010000000010000000000100011000010001100001000000001000000000010001010010000101001000010100100001010010000110000100011000010001100001000110000100011000010001100001000101001000010100100010000010001000, INIT_5=256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100, INIT_6=256'b1000010100100001010010000101001000011000010001100001000110000100011000010010000001001000000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010, INIT_7=256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100000000100000000001000110000100011000010000000010000000000100010100, INIT_8=256'b0010001000001000100000100010000010001000001000100000100010000010000110101100011010110000000100000000010000011010110001101011000101001000010100100001101011000110101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000, INIT_9=256'b0001101011000110101100000001000000000100000110101100011010110001010010000101001000011010110001101011000101001000010100100001010010000101001000010100100001010010000110101100011010110000000100000000010000011010110001101011000101001000010100100010000010001000, INIT_A=256'b0000010010000001000101000100010100010001100100000110010000000001000000000100000110010000011001000001010001000101000100010100010001010001000101000100010100010001100100000110010000010100010001010001000110010000011001000000000100000000010000011001000001100100, INIT_B=256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100011001000001100100000101000100010100010001100100000110010000000001000000000100000110010000011001000010000001001000000100100000010010000001001000000100100000010010, INIT_C=256'b0101000100000000010000000010000110001000011000100000000001000000001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000, INIT_D=256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100100000100010000010000110001000011000100001100010000110001000010100010001010001000101000100, INIT_E=256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000, INIT_F=256'b0000010010000001000101000100010100010001100010000110001000011000100001100010000110001000011000100001010001000101000100010100010001010001000000000100000000100001100010000110001000000000010000000010000110001000011000100001100010000110001000011000100001100010, INIT_10=256'b1000010100100001010010000101001000000010110000001011000101101100010110110000001011000000101100100000100010000010000110001000011000100001100010000110001000011000100001100010000110001000011000100010000001001000000100100000010010000001001000000100100000010010, INIT_11=256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000000010110000001011000101101100010110110000001011000000101100010100100001010010000000101100000010110001010010000101001000010100, INIT_12=256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000, INIT_13=256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000 */ ;   // D:/Efinix/Design/Manchester/McstDecoe_800M_LVDS/McstCodec/Source/ManchesterCodec.v(863)
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .READ_WIDTH = 10;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .WRITE_WIDTH = 10;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .WCLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .WCLKE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .WE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .RCLK_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .RE_POLARITY = 1'b1;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_0 = 256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_1 = 256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_2 = 256'b0101000100010100010001010001000000010000000001000001010001000101000100000001000000000100000101010000010101000000000100000000010000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_3 = 256'b0010001000001000100000100010000010001000001000100000100010000010000110000100011000010001100001000110000100011000010001100001000110000100011000010010000001001000000100000001000000000100000101010000010101000000000100000000010000010100010001010001000101000100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_4 = 256'b0001100001000110000100011000010001100001000110000100011000010000000010000000000100011000010001100001000000001000000000010001010010000101001000010100100001010010000110000100011000010001100001000110000100011000010001100001000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_5 = 256'b0000010010000001000101000100010100010000000100000000010000010101000001010100000000010000000001000001010001000101000100010100010001010001000101000100010100010000000100000000010000010100010001010001000000010000000001000001010100000101010000000001000000000100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_6 = 256'b1000010100100001010010000101001000011000010001100001000110000100011000010010000001001000000100000001000000000100000101000100010100010000000100000000010000010101000001010100000000010000000001000010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_7 = 256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100000000100000000001000110000100011000010000000010000000000100010100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_8 = 256'b0010001000001000100000100010000010001000001000100000100010000010000110101100011010110000000100000000010000011010110001101011000101001000010100100001101011000110101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_9 = 256'b0001101011000110101100000001000000000100000110101100011010110001010010000101001000011010110001101011000101001000010100100001010010000101001000010100100001010010000110101100011010110000000100000000010000011010110001101011000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_A = 256'b0000010010000001000101000100010100010001100100000110010000000001000000000100000110010000011001000001010001000101000100010100010001010001000101000100010100010001100100000110010000010100010001010001000110010000011001000000000100000000010000011001000001100100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_B = 256'b0100000000010000000001000000000100100000010010000001001000000100100000010001010001000101000100011001000001100100000101000100010100010001100100000110010000000001000000000100000110010000011001000010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_C = 256'b0101000100000000010000000010000110001000011000100000000001000000001000011000100001100010000110001000011000100001100010000110001000011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000100000000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_D = 256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100100000100010000010000110001000011000100001100010000110001000010100010001010001000101000100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_E = 256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_F = 256'b0000010010000001000101000100010100010001100010000110001000011000100001100010000110001000011000100001010001000101000100010100010001010001000000000100000000100001100010000110001000000000010000000010000110001000011000100001100010000110001000011000100001100010;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_10 = 256'b1000010100100001010010000101001000000010110000001011000101101100010110110000001011000000101100100000100010000010000110001000011000100001100010000110001000011000100001100010000110001000011000100010000001001000000100100000010010000001001000000100100000010010;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_11 = 256'b0000001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100001100010000110001000000010110000001011000101101100010110110000001011000000101100010100100001010010000000101100000010110001010010000101001000010100;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_12 = 256'b0010001000001000100000100010000010001000001000100000100010000010000000101100000010110001011011000101101100000010110000001011000101001000010100100000001011000000101100010100100001010010001000001000100000100010000010001000001000000000100000000010000000001000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .INIT_13 = 256'b0000001011000000101100010110110001011011000000101100000010110001010010000101001000000010110000001011000101001000010100100001010010000101001000010100100001010010000000101100000010110001011011000101101100000010110000001011000101001000010100100010000010001000;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .OUTPUT_REG = 1'b0;
    defparam \U2_McstDecode/U3_RearMcstDecRom/U2_McstDecode .WRITE_MODE = "READ_FIRST";
    EFX_LUT4 LUT__1151 (.I0(n765), .I1(\LinkCnt[5] ), .I2(\LinkCnt[6] ), 
            .O(n766)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__1151.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__1152 (.I0(\LinkCnt[20] ), .I1(\LinkCnt[21] ), .I2(\LinkCnt[22] ), 
            .I3(\LinkCnt[23] ), .O(n767)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1152.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1153 (.I0(\LinkCnt[12] ), .I1(\LinkCnt[16] ), .I2(\LinkCnt[17] ), 
            .I3(\LinkCnt[19] ), .O(n768)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1153.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1154 (.I0(\LinkCnt[13] ), .I1(\LinkCnt[14] ), .I2(\LinkCnt[15] ), 
            .O(n769)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__1154.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__1155 (.I0(n767), .I1(n768), .I2(n769), .O(n770)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__1155.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__1156 (.I0(\LinkCnt[2] ), .I1(\LinkCnt[3] ), .I2(\LinkCnt[4] ), 
            .I3(\LinkCnt[11] ), .O(n771)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1156.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1157 (.I0(\LinkCnt[0] ), .I1(\LinkCnt[1] ), .I2(\LinkCnt[18] ), 
            .I3(\LinkCnt[24] ), .O(n772)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1157.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1158 (.I0(n766), .I1(n770), .I2(n771), .I3(n772), 
            .O(RxMcstLink)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1158.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1159 (.I0(\RxClkCnt[0] ), .I1(\RxNrzDAva[0] ), .I2(\RxNrzDAva[1] ), 
            .O(n773)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6969 */ ;
    defparam LUT__1159.LUTMASK = 16'h6969;
    EFX_LUT4 LUT__1160 (.I0(\RxNrzDAvaReg[0] ), .I1(\RxNrzDAvaReg[1] ), 
            .I2(\RxNrzFlagReg[2] ), .O(n774)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__1160.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__1161 (.I0(\RxNrzDAva[1] ), .I1(\RxNrzDAva[0] ), .I2(n774), 
            .O(n775)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0707 */ ;
    defparam LUT__1161.LUTMASK = 16'h0707;
    EFX_LUT4 LUT__1162 (.I0(\RxNrzDAva[0] ), .I1(\RxNrzDAva[1] ), .O(n414)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'heeee */ ;
    defparam LUT__1162.LUTMASK = 16'heeee;
    EFX_LUT4 LUT__1163 (.I0(\RxNrzFlagReg[3] ), .I1(\RxNrzFlagReg[2] ), 
            .I2(n414), .O(n401)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'he0e0 */ ;
    defparam LUT__1163.LUTMASK = 16'he0e0;
    EFX_LUT4 LUT__1164 (.I0(n773), .I1(n775), .I2(n401), .O(n394)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hc5c5 */ ;
    defparam LUT__1164.LUTMASK = 16'hc5c5;
    EFX_LUT4 LUT__1165 (.I0(\RxDataSft[2] ), .I1(\RxDataSft[1] ), .I2(\RxNrzDAva[0] ), 
            .I3(\RxNrzDAva[1] ), .O(n395)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1165.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1166 (.I0(\RxClkCnt[0] ), .I1(\RxNrzDAva[0] ), .I2(\RxNrzDAva[1] ), 
            .I3(\RxClkCnt[1] ), .O(n397)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'he800 */ ;
    defparam LUT__1166.LUTMASK = 16'he800;
    EFX_LUT4 LUT__1167 (.I0(\RxDataSft[1] ), .I1(\RxDataSft[0] ), .I2(\RxClkCnt[0] ), 
            .O(n398)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1167.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1168 (.I0(\RxNrzFlagReg[1] ), .I1(\RxNrzFlagReg[0] ), 
            .I2(n414), .O(n574)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'he0e0 */ ;
    defparam LUT__1168.LUTMASK = 16'he0e0;
    EFX_LUT4 LUT__1169 (.I0(\RxDataAvaReg[3] ), .I1(\RxDataAvaReg[1] ), 
            .I2(RxNibbEn), .O(n405)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'he0e0 */ ;
    defparam LUT__1169.LUTMASK = 16'he0e0;
    EFX_LUT4 LUT__1170 (.I0(\RxDataAvaReg[1] ), .I1(\RxDataAvaReg[2] ), 
            .I2(n405), .I3(\RxDataAvaReg[0] ), .O(n571)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1f00 */ ;
    defparam LUT__1170.LUTMASK = 16'h1f00;
    EFX_LUT4 LUT__1171 (.I0(n574), .I1(n571), .O(n400)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'heeee */ ;
    defparam LUT__1171.LUTMASK = 16'heeee;
    EFX_LUT4 LUT__1172 (.I0(\RxClkReg[0] ), .I1(\RxClkReg[1] ), .O(n407)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6666 */ ;
    defparam LUT__1172.LUTMASK = 16'h6666;
    EFX_LUT4 LUT__1173 (.I0(\RxNrzDAva[0] ), .I1(\U2_McstDecode/RDecFlagEnd ), 
            .O(n413)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1173.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1174 (.I0(\U2_McstDecode/McstDataIn[6] ), .I1(\U2_McstDecode/McstDataIn[7] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .O(n776)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1174.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1175 (.I0(\U2_McstDecode/McstDataIn[4] ), .I1(\U2_McstDecode/McstDataIn[5] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .O(n777)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1175.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1176 (.I0(n776), .I1(n777), .I2(\U2_McstDecode/DelimitPos[1] ), 
            .O(n778)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h5353 */ ;
    defparam LUT__1176.LUTMASK = 16'h5353;
    EFX_LUT4 LUT__1177 (.I0(\U2_McstDecode/McstDataIn[0] ), .I1(\U2_McstDecode/McstDataIn[1] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .O(n779)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1177.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1178 (.I0(\U2_McstDecode/McstDataIn[2] ), .I1(\U2_McstDecode/McstDataIn[3] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .O(n780)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1178.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1179 (.I0(n779), .I1(n780), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .I3(\U2_McstDecode/DelimitPos[1] ), .O(n781)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0305 */ ;
    defparam LUT__1179.LUTMASK = 16'h0305;
    EFX_LUT4 LUT__1180 (.I0(n778), .I1(\U2_McstDecode/DelimitPos[2] ), .I2(n781), 
            .O(n415)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf8f8 */ ;
    defparam LUT__1180.LUTMASK = 16'hf8f8;
    EFX_LUT4 LUT__1181 (.I0(\U2_McstDecode/McstDataIn[1] ), .I1(\U2_McstDecode/McstDataIn[3] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n782)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0305 */ ;
    defparam LUT__1181.LUTMASK = 16'h0305;
    EFX_LUT4 LUT__1182 (.I0(\U2_McstDecode/McstDataIn[2] ), .I1(\U2_McstDecode/McstDataIn[4] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .I3(\U2_McstDecode/DelimitPos[0] ), 
            .O(n783)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3500 */ ;
    defparam LUT__1182.LUTMASK = 16'h3500;
    EFX_LUT4 LUT__1183 (.I0(n782), .I1(n783), .I2(n858), .I3(\U2_McstDecode/DelimitPos[2] ), 
            .O(n416)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf011 */ ;
    defparam LUT__1183.LUTMASK = 16'hf011;
    EFX_LUT4 LUT__1184 (.I0(\U2_McstDecode/DelimitPos[1] ), .I1(\U2_McstDecode/DelimitPos[2] ), 
            .O(n784)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__1184.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__1185 (.I0(\U2_McstDecode/McstDataIn[10] ), .I1(\U2_McstDecode/McstDataIn[8] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n785)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1185.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1186 (.I0(\U2_McstDecode/McstDataIn[11] ), .I1(\U2_McstDecode/McstDataIn[9] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n786)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1186.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1187 (.I0(\U2_McstDecode/DelimitPos[1] ), .I1(\U2_McstDecode/DelimitPos[2] ), 
            .O(n787)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1187.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1188 (.I0(n785), .I1(n786), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .I3(n787), .O(n788)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3500 */ ;
    defparam LUT__1188.LUTMASK = 16'h3500;
    EFX_LUT4 LUT__1189 (.I0(n776), .I1(n777), .I2(\U2_McstDecode/DelimitPos[1] ), 
            .I3(\U2_McstDecode/DelimitPos[2] ), .O(n789)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf53f */ ;
    defparam LUT__1189.LUTMASK = 16'hf53f;
    EFX_LUT4 LUT__1190 (.I0(n784), .I1(n780), .I2(n788), .I3(n789), 
            .O(n417)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0700 */ ;
    defparam LUT__1190.LUTMASK = 16'h0700;
    EFX_LUT4 LUT__1191 (.I0(\U2_McstDecode/DelimitPos[0] ), .I1(\U2_McstDecode/DelimitPos[1] ), 
            .I2(\U2_McstDecode/McstDataIn[7] ), .O(n790)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1010 */ ;
    defparam LUT__1191.LUTMASK = 16'h1010;
    EFX_LUT4 LUT__1192 (.I0(\U2_McstDecode/McstDataIn[8] ), .I1(\U2_McstDecode/McstDataIn[10] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n791)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1192.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1193 (.I0(\U2_McstDecode/DelimitPos[1] ), .I1(\U2_McstDecode/McstDataIn[9] ), 
            .I2(n791), .I3(\U2_McstDecode/DelimitPos[0] ), .O(n792)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf077 */ ;
    defparam LUT__1193.LUTMASK = 16'hf077;
    EFX_LUT4 LUT__1194 (.I0(n790), .I1(n792), .I2(n860), .I3(\U2_McstDecode/DelimitPos[2] ), 
            .O(n418)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hbbf0 */ ;
    defparam LUT__1194.LUTMASK = 16'hbbf0;
    EFX_LUT4 LUT__1195 (.I0(\U2_McstDecode/McstDataIn[9] ), .I1(\U2_McstDecode/McstDataIn[11] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n793)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1195.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1196 (.I0(n793), .I1(n791), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n794)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h5353 */ ;
    defparam LUT__1196.LUTMASK = 16'h5353;
    EFX_LUT4 LUT__1197 (.I0(n794), .I1(n778), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n419)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1197.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1198 (.I0(\U2_McstDecode/McstDataIn[10] ), .I1(\U2_McstDecode/McstDataIn[12] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n795)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1198.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1199 (.I0(n795), .I1(n793), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n796)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'ha3a3 */ ;
    defparam LUT__1199.LUTMASK = 16'ha3a3;
    EFX_LUT4 LUT__1200 (.I0(n796), .I1(n858), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n420)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1200.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1201 (.I0(\U2_McstDecode/DelimitPos[1] ), .I1(\U2_McstDecode/DelimitPos[2] ), 
            .O(n797)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h9999 */ ;
    defparam LUT__1201.LUTMASK = 16'h9999;
    EFX_LUT4 LUT__1202 (.I0(n785), .I1(n786), .I2(n797), .I3(\U2_McstDecode/DelimitPos[0] ), 
            .O(n798)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0305 */ ;
    defparam LUT__1202.LUTMASK = 16'h0305;
    EFX_LUT4 LUT__1203 (.I0(n776), .I1(n784), .O(n799)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1203.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1204 (.I0(n787), .I1(n862), .I2(n798), .I3(n799), 
            .O(n421)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0007 */ ;
    defparam LUT__1204.LUTMASK = 16'h0007;
    EFX_LUT4 LUT__1205 (.I0(\U2_McstDecode/McstDataIn[11] ), .I1(\U2_McstDecode/McstDataIn[13] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n800)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1205.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1206 (.I0(\U2_McstDecode/McstDataIn[12] ), .I1(\U2_McstDecode/McstDataIn[14] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n801)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1206.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1207 (.I0(n800), .I1(n801), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n802)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1207.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1208 (.I0(n790), .I1(n792), .I2(n802), .I3(\U2_McstDecode/DelimitPos[2] ), 
            .O(n422)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf0bb */ ;
    defparam LUT__1208.LUTMASK = 16'hf0bb;
    EFX_LUT4 LUT__1209 (.I0(\U2_McstDecode/McstDataIn[13] ), .I1(\U2_McstDecode/McstDataIn[15] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n803)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1209.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1210 (.I0(n803), .I1(n801), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n804)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h5353 */ ;
    defparam LUT__1210.LUTMASK = 16'h5353;
    EFX_LUT4 LUT__1211 (.I0(n804), .I1(n794), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n423)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1211.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1212 (.I0(\U2_McstDecode/McstDataIn[14] ), .I1(\U2_McstDecode/McstDataIn[16] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n805)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1212.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1213 (.I0(n805), .I1(n803), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n806)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'ha3a3 */ ;
    defparam LUT__1213.LUTMASK = 16'ha3a3;
    EFX_LUT4 LUT__1214 (.I0(n806), .I1(n796), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n424)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1214.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1215 (.I0(n785), .I1(n786), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .I3(n784), .O(n807)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hca00 */ ;
    defparam LUT__1215.LUTMASK = 16'hca00;
    EFX_LUT4 LUT__1216 (.I0(\U2_McstDecode/McstDataIn[16] ), .I1(\U2_McstDecode/McstDataIn[17] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .O(n808)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1216.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1217 (.I0(n808), .I1(n787), .O(n809)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4444 */ ;
    defparam LUT__1217.LUTMASK = 16'h4444;
    EFX_LUT4 LUT__1218 (.I0(n797), .I1(n862), .I2(n807), .I3(n809), 
            .O(n425)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfff1 */ ;
    defparam LUT__1218.LUTMASK = 16'hfff1;
    EFX_LUT4 LUT__1219 (.I0(\U2_McstDecode/McstDataIn[15] ), .I1(\U2_McstDecode/McstDataIn[17] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n810)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1219.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1220 (.I0(\U2_McstDecode/McstDataIn[16] ), .I1(\U2_McstDecode/McstDataIn[18] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n811)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1220.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1221 (.I0(n810), .I1(n811), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n812)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1221.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1222 (.I0(n812), .I1(n802), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n426)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1222.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1223 (.I0(\U2_McstDecode/McstDataIn[17] ), .I1(\U2_McstDecode/McstDataIn[19] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n813)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1223.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1224 (.I0(n813), .I1(n811), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n814)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h5353 */ ;
    defparam LUT__1224.LUTMASK = 16'h5353;
    EFX_LUT4 LUT__1225 (.I0(n814), .I1(n804), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n427)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1225.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1226 (.I0(\U2_McstDecode/McstDataIn[18] ), .I1(\U2_McstDecode/McstDataIn[20] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .O(n815)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1226.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1227 (.I0(n815), .I1(n813), .I2(\U2_McstDecode/DelimitPos[0] ), 
            .O(n816)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'ha3a3 */ ;
    defparam LUT__1227.LUTMASK = 16'ha3a3;
    EFX_LUT4 LUT__1228 (.I0(n816), .I1(n806), .I2(\U2_McstDecode/DelimitPos[2] ), 
            .O(n428)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1228.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1229 (.I0(\U2_McstDecode/McstDataIn[20] ), .I1(\U2_McstDecode/McstDataIn[21] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(n787), .O(n817)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3500 */ ;
    defparam LUT__1229.LUTMASK = 16'h3500;
    EFX_LUT4 LUT__1230 (.I0(\U2_McstDecode/McstDataIn[18] ), .I1(\U2_McstDecode/McstDataIn[19] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .O(n818)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1230.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1231 (.I0(n818), .I1(n808), .I2(\U2_McstDecode/DelimitPos[1] ), 
            .I3(\U2_McstDecode/DelimitPos[2] ), .O(n819)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf53f */ ;
    defparam LUT__1231.LUTMASK = 16'hf53f;
    EFX_LUT4 LUT__1232 (.I0(n784), .I1(n862), .I2(n817), .I3(n819), 
            .O(n429)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0700 */ ;
    defparam LUT__1232.LUTMASK = 16'h0700;
    EFX_LUT4 LUT__1233 (.I0(\U2_McstDecode/McstDataIn[19] ), .I1(\U2_McstDecode/McstDataIn[21] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n820)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0305 */ ;
    defparam LUT__1233.LUTMASK = 16'h0305;
    EFX_LUT4 LUT__1234 (.I0(\U2_McstDecode/McstDataIn[20] ), .I1(\U2_McstDecode/McstDataIn[22] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .I3(\U2_McstDecode/DelimitPos[0] ), 
            .O(n821)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3500 */ ;
    defparam LUT__1234.LUTMASK = 16'h3500;
    EFX_LUT4 LUT__1235 (.I0(n820), .I1(n821), .I2(n812), .I3(\U2_McstDecode/DelimitPos[2] ), 
            .O(n430)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h11f0 */ ;
    defparam LUT__1235.LUTMASK = 16'h11f0;
    EFX_LUT4 LUT__1236 (.I0(\U2_McstDecode/McstDataIn[20] ), .I1(\U2_McstDecode/McstDataIn[21] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .I3(\U2_McstDecode/DelimitPos[0] ), 
            .O(n822)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0305 */ ;
    defparam LUT__1236.LUTMASK = 16'h0305;
    EFX_LUT4 LUT__1237 (.I0(\U2_McstDecode/McstDataIn[22] ), .I1(\U2_McstDecode/McstDataIn[23] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n823)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3500 */ ;
    defparam LUT__1237.LUTMASK = 16'h3500;
    EFX_LUT4 LUT__1238 (.I0(n822), .I1(n823), .I2(n814), .I3(\U2_McstDecode/DelimitPos[2] ), 
            .O(n431)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h11f0 */ ;
    defparam LUT__1238.LUTMASK = 16'h11f0;
    EFX_LUT4 LUT__1239 (.I0(\U2_McstDecode/McstDataIn[21] ), .I1(\U2_McstDecode/McstDataIn[23] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n824)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0305 */ ;
    defparam LUT__1239.LUTMASK = 16'h0305;
    EFX_LUT4 LUT__1240 (.I0(\U2_McstDecode/McstDataIn[22] ), .I1(\U2_McstDecode/McstDataIn[24] ), 
            .I2(\U2_McstDecode/DelimitPos[1] ), .I3(\U2_McstDecode/DelimitPos[0] ), 
            .O(n825)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3500 */ ;
    defparam LUT__1240.LUTMASK = 16'h3500;
    EFX_LUT4 LUT__1241 (.I0(n824), .I1(n825), .I2(n816), .I3(\U2_McstDecode/DelimitPos[2] ), 
            .O(n432)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h11f0 */ ;
    defparam LUT__1241.LUTMASK = 16'h11f0;
    EFX_LUT4 LUT__1242 (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[4] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[5] ), .I2(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[6] ), 
            .I3(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[7] ), .O(n826)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0001 */ ;
    defparam LUT__1242.LUTMASK = 16'h0001;
    EFX_LUT4 LUT__1243 (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[0] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[1] ), .I2(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[2] ), 
            .I3(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[3] ), .O(n827)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0001 */ ;
    defparam LUT__1243.LUTMASK = 16'h0001;
    EFX_LUT4 LUT__1244 (.I0(n826), .I1(n827), .O(n443)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1244.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1245 (.I0(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[4] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[5] ), .I2(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[6] ), 
            .I3(\U2_McstDecode/U1_McstDelimit/DmltErrCnt[7] ), .O(n828)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1245.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1246 (.I0(n828), .I1(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n444)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1246.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1247 (.I0(DmltError), .I1(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1] ), 
            .O(n447)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4444 */ ;
    defparam LUT__1247.LUTMASK = 16'h4444;
    EFX_LUT4 LUT__1248 (.I0(\U2_McstDecode/DelimitPos[0] ), .I1(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0] ), 
            .I2(n784), .I3(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1] ), 
            .O(n449)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4000 */ ;
    defparam LUT__1248.LUTMASK = 16'h4000;
    EFX_LUT4 LUT__1249 (.I0(\U1_ClkSmooth/ClkDiffCnt[5] ), .I1(\U1_ClkSmooth/ClkDiffCnt[4] ), 
            .I2(\U1_ClkSmooth/ClkDiffCnt[6] ), .I3(\U1_ClkSmooth/ClkDiffCnt[7] ), 
            .O(n829)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4000 */ ;
    defparam LUT__1249.LUTMASK = 16'h4000;
    EFX_LUT4 LUT__1250 (.I0(\U1_ClkSmooth/ClkDiffCnt[0] ), .I1(\U1_ClkSmooth/ClkDiffCnt[1] ), 
            .I2(\U1_ClkSmooth/ClkDiffCnt[2] ), .I3(\U1_ClkSmooth/ClkDiffCnt[3] ), 
            .O(n830)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__1250.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__1251 (.I0(n829), .I1(n830), .O(n451)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7777 */ ;
    defparam LUT__1251.LUTMASK = 16'h7777;
    EFX_LUT4 LUT__1252 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[2] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[0] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n831)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1252.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1253 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[1] ), 
            .I1(n831), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n455)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1253.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1254 (.I0(n50), .I1(n25), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n459)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1254.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1255 (.I0(\U2_McstDecode/U1_McstDelimit/AdjustCnt[0] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/AdjustCnt[2] ), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtPosHit ), 
            .O(n460)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hc5c5 */ ;
    defparam LUT__1255.LUTMASK = 16'hc5c5;
    EFX_LUT4 LUT__1256 (.I0(\U2_McstDecode/U1_McstDelimit/RdDlmtPosHit ), 
            .I1(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n461)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__1256.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__1257 (.I0(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), .I1(\U2_McstDecode/U1_McstDelimit/AdjustCnt[0] ), 
            .I2(\U2_McstDecode/U1_McstDelimit/AdjustCnt[1] ), .I3(\U2_McstDecode/U1_McstDelimit/AdjustCnt[2] ), 
            .O(n832)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfe7f */ ;
    defparam LUT__1257.LUTMASK = 16'hfe7f;
    EFX_LUT4 LUT__1258 (.I0(n832), .I1(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), 
            .O(n462)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4444 */ ;
    defparam LUT__1258.LUTMASK = 16'h4444;
    EFX_LUT4 LUT__1259 (.I0(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0] ), 
            .I1(\U2_McstDecode/DelimitPos[0] ), .I2(\U2_McstDecode/DelimitPos[1] ), 
            .O(n463)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h9696 */ ;
    defparam LUT__1259.LUTMASK = 16'h9696;
    EFX_LUT4 LUT__1260 (.I0(DmltError), .I1(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n833)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4551 */ ;
    defparam LUT__1260.LUTMASK = 16'h4551;
    EFX_LUT4 LUT__1261 (.I0(n833), .I1(\U2_McstDecode/DelimitPos[2] ), .O(n464)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h9999 */ ;
    defparam LUT__1261.LUTMASK = 16'h9999;
    EFX_LUT4 LUT__1262 (.I0(DmltError), .I1(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1] ), 
            .O(n465)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__1262.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__1263 (.I0(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[0] ), 
            .I1(n787), .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/U1_McstDelimit/DlmtPosAdj[1] ), 
            .O(n466)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4000 */ ;
    defparam LUT__1263.LUTMASK = 16'h4000;
    EFX_LUT4 LUT__1264 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[3] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[1] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n834)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1264.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1265 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[2] ), 
            .I1(n834), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n478)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1265.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1266 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[4] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[2] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n835)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1266.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1267 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[3] ), 
            .I1(n835), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n479)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1267.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1268 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[5] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[3] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n836)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1268.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1269 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[4] ), 
            .I1(n836), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n480)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1269.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1270 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[6] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[4] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n837)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1270.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1271 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[5] ), 
            .I1(n837), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n481)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1271.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1272 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[7] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[5] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n838)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1272.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1273 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[6] ), 
            .I1(n838), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n482)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1273.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1274 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[8] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[6] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n839)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1274.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1275 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[7] ), 
            .I1(n839), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n483)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1275.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1276 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[9] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[7] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n840)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1276.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1277 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[8] ), 
            .I1(n840), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n484)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1277.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1278 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[10] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[8] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n841)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1278.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1279 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[9] ), 
            .I1(n841), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n485)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1279.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1280 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[11] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[9] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n842)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1280.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1281 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[10] ), 
            .I1(n842), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n486)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1281.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1282 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[12] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[10] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n843)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1282.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1283 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[11] ), 
            .I1(n843), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n487)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1283.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1284 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[13] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[11] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n844)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1284.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1285 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[12] ), 
            .I1(n844), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n488)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1285.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1286 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[14] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[12] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n845)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1286.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1287 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[13] ), 
            .I1(n845), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n489)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1287.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1288 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[15] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[13] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n846)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1288.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1289 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[14] ), 
            .I1(n846), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n490)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1289.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1290 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[16] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[14] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n847)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1290.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1291 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[15] ), 
            .I1(n847), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n491)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1291.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1292 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[17] ), 
            .I1(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[15] ), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), 
            .O(n848)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3535 */ ;
    defparam LUT__1292.LUTMASK = 16'h3535;
    EFX_LUT4 LUT__1293 (.I0(\U2_McstDecode/U1_McstDelimit/PrimitDataReg[16] ), 
            .I1(n848), .I2(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n492)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1293.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1294 (.I0(n274), .I1(n298), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n493)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1294.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1295 (.I0(n272), .I1(n285), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n494)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1295.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1296 (.I0(n270), .I1(n283), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n495)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1296.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1297 (.I0(n268), .I1(n281), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n496)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1297.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1298 (.I0(n266), .I1(n279), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n497)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1298.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1299 (.I0(n264), .I1(n277), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n498)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1299.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1300 (.I0(n263), .I1(n276), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtError ), 
            .O(n499)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1300.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1301 (.I0(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), .I1(\U2_McstDecode/U1_McstDelimit/AdjustCnt[0] ), 
            .I2(\U2_McstDecode/U1_McstDelimit/AdjustCnt[1] ), .O(n849)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6969 */ ;
    defparam LUT__1301.LUTMASK = 16'h6969;
    EFX_LUT4 LUT__1302 (.I0(\U2_McstDecode/U1_McstDelimit/AdjustCnt[2] ), 
            .I1(n849), .I2(\U2_McstDecode/U1_McstDelimit/RdDlmtPosHit ), 
            .O(n500)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hacac */ ;
    defparam LUT__1302.LUTMASK = 16'hacac;
    EFX_LUT4 LUT__1303 (.I0(\U2_McstDecode/U1_McstDelimit/RdAdjustDir ), .I1(\U2_McstDecode/U1_McstDelimit/AdjustCnt[0] ), 
            .I2(\U2_McstDecode/U1_McstDelimit/AdjustCnt[1] ), .I3(\U2_McstDecode/U1_McstDelimit/AdjustCnt[2] ), 
            .O(n501)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h80fe */ ;
    defparam LUT__1303.LUTMASK = 16'h80fe;
    EFX_LUT4 LUT__1304 (.I0(\U2_McstDecode/U1_McstDelimit/RdDlmtPosHit ), 
            .I1(\U2_McstDecode/U1_McstDelimit/RdAdjustEn ), .O(n502)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4444 */ ;
    defparam LUT__1304.LUTMASK = 16'h4444;
    EFX_LUT4 LUT__1305 (.I0(\RxClkCnt[0] ), .I1(\RxNrzDAva[0] ), .I2(\RxNrzDAva[1] ), 
            .I3(\RxClkCnt[1] ), .O(n850)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h17e8 */ ;
    defparam LUT__1305.LUTMASK = 16'h17e8;
    EFX_LUT4 LUT__1306 (.I0(n850), .I1(n775), .I2(n401), .O(n557)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3a3a */ ;
    defparam LUT__1306.LUTMASK = 16'h3a3a;
    EFX_LUT4 LUT__1307 (.I0(\RxDataSft[3] ), .I1(\RxDataSft[2] ), .I2(\RxNrzDAva[0] ), 
            .I3(\RxNrzDAva[1] ), .O(n562)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1307.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1308 (.I0(\RxDataSft[4] ), .I1(\RxDataSft[3] ), .I2(\RxNrzDAva[0] ), 
            .I3(\RxNrzDAva[1] ), .O(n563)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1308.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1309 (.I0(\RxNrzData[0] ), .I1(\RxDataSft[4] ), .I2(\RxNrzDAva[0] ), 
            .I3(\RxNrzDAva[1] ), .O(n564)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1309.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1310 (.I0(\RxNrzData[1] ), .I1(\RxNrzData[0] ), .I2(\RxNrzDAva[0] ), 
            .I3(\RxNrzDAva[1] ), .O(n565)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1310.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1311 (.I0(\RxDataSft[2] ), .I1(\RxDataSft[1] ), .I2(\RxClkCnt[0] ), 
            .O(n566)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1311.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1312 (.I0(\RxDataSft[3] ), .I1(\RxDataSft[2] ), .I2(\RxClkCnt[0] ), 
            .O(n567)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1312.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1313 (.I0(\RxDataSft[4] ), .I1(\RxDataSft[3] ), .I2(\RxClkCnt[0] ), 
            .O(n568)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcaca */ ;
    defparam LUT__1313.LUTMASK = 16'hcaca;
    EFX_LUT4 LUT__1314 (.I0(n401), .I1(n574), .O(n572)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'heeee */ ;
    defparam LUT__1314.LUTMASK = 16'heeee;
    EFX_LUT4 LUT__1315 (.I0(\RxDataAvaReg[0] ), .I1(\RxDataAvaReg[3] ), 
            .I2(n405), .I3(\RxDataAvaReg[2] ), .O(n573)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1f00 */ ;
    defparam LUT__1315.LUTMASK = 16'h1f00;
    EFX_LUT4 LUT__1316 (.I0(n56), .I1(n183), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n584)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1316.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1317 (.I0(RxNibbEn), .I1(RxByteGen), .I2(\U1_ClkSmooth/ClkOutEn ), 
            .O(n585)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7878 */ ;
    defparam LUT__1317.LUTMASK = 16'h7878;
    EFX_LUT4 LUT__1318 (.I0(\U1_ClkSmooth/ClkDiffCnt[4] ), .I1(\U1_ClkSmooth/ClkDiffCnt[6] ), 
            .I2(\U1_ClkSmooth/ClkDiffCnt[7] ), .I3(\U1_ClkSmooth/ClkDiffCnt[5] ), 
            .O(n851)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0100 */ ;
    defparam LUT__1318.LUTMASK = 16'h0100;
    EFX_LUT4 LUT__1319 (.I0(\U1_ClkSmooth/ClkDiffCnt[0] ), .I1(\U1_ClkSmooth/ClkDiffCnt[1] ), 
            .I2(\U1_ClkSmooth/ClkDiffCnt[2] ), .I3(\U1_ClkSmooth/ClkDiffCnt[3] ), 
            .O(n852)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0001 */ ;
    defparam LUT__1319.LUTMASK = 16'h0001;
    EFX_LUT4 LUT__1320 (.I0(n851), .I1(n852), .O(n586)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1320.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1321 (.I0(RxRstClk), .I1(\U1_ClkSmooth/ClkGen[7] ), .O(n587)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4444 */ ;
    defparam LUT__1321.LUTMASK = 16'h4444;
    EFX_LUT4 LUT__1322 (.I0(n260), .I1(n175), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n603)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1322.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1323 (.I0(n257), .I1(n173), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n604)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1323.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1324 (.I0(n251), .I1(n168), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n605)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1324.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1325 (.I0(n242), .I1(n159), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n606)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1325.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1326 (.I0(\U1_ClkSmooth/ClkDiffCnt[5] ), .I1(n157), .I2(\U1_ClkSmooth/ClkOutEn ), 
            .O(n853)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hc5c5 */ ;
    defparam LUT__1326.LUTMASK = 16'hc5c5;
    EFX_LUT4 LUT__1327 (.I0(n240), .I1(n853), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n607)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1327.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1328 (.I0(n233), .I1(n153), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n609)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1328.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1329 (.I0(n228), .I1(n152), .I2(RxNibbEn), .I3(RxByteGen), 
            .O(n610)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'haccc */ ;
    defparam LUT__1329.LUTMASK = 16'haccc;
    EFX_LUT4 LUT__1330 (.I0(\U1_RxFifo/FifoWrAddrCnt[1] ), .I1(\U1_RxFifo/FifoWrAddrCnt[0] ), 
            .I2(\U1_RxFifo/WrAddrSync ), .I3(\U1_RxFifo/FifoWrAddrCnt[2] ), 
            .O(n611)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0708 */ ;
    defparam LUT__1330.LUTMASK = 16'h0708;
    EFX_LUT4 LUT__1331 (.I0(\U1_RxFifo/WrAddrSync ), .I1(\U1_RxFifo/FifoWrEn ), 
            .O(n612)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1111 */ ;
    defparam LUT__1331.LUTMASK = 16'h1111;
    EFX_LUT4 LUT__1332 (.I0(\U1_RxFifo/WrAddrSync ), .I1(\U1_RxFifo/FifoWrAddrCnt[1] ), 
            .I2(\U1_RxFifo/FifoWrAddrCnt[0] ), .O(n613)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1414 */ ;
    defparam LUT__1332.LUTMASK = 16'h1414;
    EFX_LUT4 LUT__1333 (.I0(\U1_RxFifo/WrAddrSync ), .I1(\U1_RxFifo/FifoWrAddrCnt[0] ), 
            .O(n614)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hbbbb */ ;
    defparam LUT__1333.LUTMASK = 16'hbbbb;
    EFX_LUT4 LUT__1334 (.I0(\U1_RxFifo/FifoWrData[4] ), .I1(RxDataAva), 
            .I2(RxNibbEn), .O(n615)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__1334.LUTMASK = 16'h4040;
    EFX_LUT4 LUT__1335 (.I0(\U1_RxFifo/FifoWrAddrCnt[1] ), .I1(\U1_RxFifo/FifoWrAddrCnt[0] ), 
            .I2(\U1_RxFifo/FifoWrEn ), .O(n618)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1010 */ ;
    defparam LUT__1335.LUTMASK = 16'h1010;
    EFX_LUT4 LUT__1336 (.I0(\U1_RxFifo/FifoWrAddrCnt[1] ), .I1(\U1_RxFifo/FifoWrAddrCnt[0] ), 
            .I2(\U1_RxFifo/FifoWrEn ), .O(n623)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__1336.LUTMASK = 16'h4040;
    EFX_LUT4 LUT__1337 (.I0(\U1_RxFifo/FifoWrAddrCnt[0] ), .I1(\U1_RxFifo/FifoWrAddrCnt[1] ), 
            .I2(\U1_RxFifo/FifoWrEn ), .O(n628)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__1337.LUTMASK = 16'h4040;
    EFX_LUT4 LUT__1338 (.I0(\U1_RxFifo/FifoWrAddrCnt[1] ), .I1(\U1_RxFifo/FifoWrAddrCnt[0] ), 
            .I2(\U1_RxFifo/FifoWrEn ), .O(n630)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__1338.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__1339 (.I0(\U1_RxFifo/InMiiDataEnReg[1] ), .I1(\U1_RxFifo/InMiiDataEnReg[0] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .O(n632)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4f4f */ ;
    defparam LUT__1339.LUTMASK = 16'h4f4f;
    EFX_LUT4 LUT__1340 (.I0(\U1_RxFifo/InMiiDataEnReg[1] ), .I1(\U1_RxFifo/InMiiDataEnReg[0] ), 
            .I2(RxClkEn), .O(n633)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0b0b */ ;
    defparam LUT__1340.LUTMASK = 16'h0b0b;
    EFX_LUT4 LUT__1341 (.I0(\U1_RxFifo/RdAddrLowReg[0] ), .I1(\U1_RxFifo/RdAddrLowReg[1] ), 
            .O(n638)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6666 */ ;
    defparam LUT__1341.LUTMASK = 16'h6666;
    EFX_LUT4 LUT__1342 (.I0(\U1_RxFifo/FifoWrAddrCnt[2] ), .I1(\U1_RxFifo/FifoWrAddrCnt[0] ), 
            .I2(\U1_RxFifo/CurrRdAddr[0] ), .I3(\U1_RxFifo/CurrRdAddr[2] ), 
            .O(n854)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4182 */ ;
    defparam LUT__1342.LUTMASK = 16'h4182;
    EFX_LUT4 LUT__1343 (.I0(\U1_RxFifo/FifoWrAddrCnt[1] ), .I1(\U1_RxFifo/CurrRdAddr[1] ), 
            .I2(n854), .O(n642)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h9090 */ ;
    defparam LUT__1343.LUTMASK = 16'h9090;
    EFX_LUT4 LUT__1344 (.I0(\U1_RxFifo/WrAddrLowReg[0] ), .I1(\U1_RxFifo/WrAddrLowReg[1] ), 
            .O(n644)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6666 */ ;
    defparam LUT__1344.LUTMASK = 16'h6666;
    EFX_LUT4 LUT__1345 (.I0(\U1_RxFifo/FifoRdAddrCnt[1] ), .I1(\U1_RxFifo/CurrWrAddr[1] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[2] ), .I3(\U1_RxFifo/CurrWrAddr[2] ), 
            .O(n855)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h9009 */ ;
    defparam LUT__1345.LUTMASK = 16'h9009;
    EFX_LUT4 LUT__1346 (.I0(\U1_RxFifo/FifoRdAddrCnt[0] ), .I1(\U1_RxFifo/CurrWrAddr[0] ), 
            .I2(n855), .O(n647)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h6f6f */ ;
    defparam LUT__1346.LUTMASK = 16'h6f6f;
    EFX_LUT4 LUT__1347 (.I0(\U1_RxFifo/InMiiDataEnReg[1] ), .I1(\U1_RxFifo/InMiiDataEnReg[0] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .O(n671)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4ff4 */ ;
    defparam LUT__1347.LUTMASK = 16'h4ff4;
    EFX_LUT4 LUT__1348 (.I0(\U1_RxFifo/FifoRdAddrCnt[0] ), .I1(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[2] ), .O(n856)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8787 */ ;
    defparam LUT__1348.LUTMASK = 16'h8787;
    EFX_LUT4 LUT__1349 (.I0(\U1_RxFifo/InMiiDataEnReg[1] ), .I1(\U1_RxFifo/InMiiDataEnReg[0] ), 
            .I2(n856), .O(n672)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0b0b */ ;
    defparam LUT__1349.LUTMASK = 16'h0b0b;
    EFX_LUT4 LUT__1350 (.I0(\RxNrzDAva[1] ), .I1(\U2_McstDecode/FDecFlagEnd ), 
            .O(n762)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1350.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1351 (.I0(\RxNrzDAva[0] ), .I1(\U2_McstDecode/RDecFlagStr ), 
            .O(n763)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1351.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1352 (.I0(\RxNrzDAva[1] ), .I1(\U2_McstDecode/FDecFlagStr ), 
            .O(n764)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1352.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1620 (.I0(\U2_McstDecode/McstDataIn[6] ), .I1(\U2_McstDecode/McstDataIn[8] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n857)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1620.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1149 (.I0(InMiiFull), .I1(OutMiiEmpty), .O(MiiRxErr)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__1149.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__1621 (.I0(\U2_McstDecode/McstDataIn[5] ), .I1(\U2_McstDecode/McstDataIn[7] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(n857), .O(n858)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1621.LUTMASK = 16'hfc0a;
    EFX_GBUFCE CLKBUF__1 (.CE(1'b1), .I(SysClk), .O(\SysClk~O )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_GBUFCE, CE_POLARITY=1'b1 */ ;
    defparam CLKBUF__1.CE_POLARITY = 1'b1;
    EFX_GBUFCE CLKBUF__0 (.CE(1'b1), .I(RxMcstClk), .O(\RxMcstClk_2~O )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_GBUFCE, CE_POLARITY=1'b1 */ ;
    defparam CLKBUF__0.CE_POLARITY = 1'b1;
    EFX_ADD \AUX_ADD_CI__U1_ClkSmooth/sub_9/add_2/i1  (.I0(1'b1), .I1(1'b1), 
            .CI(1'b0), .CO(n869)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;
    defparam \AUX_ADD_CI__U1_ClkSmooth/sub_9/add_2/i1 .I0_POLARITY = 1'b1;
    defparam \AUX_ADD_CI__U1_ClkSmooth/sub_9/add_2/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \AUX_ADD_CI__U2_McstDecode/U1_McstDelimit/sub_7/add_2/i1  (.I0(1'b1), 
            .I1(1'b1), .CI(1'b0), .CO(n868)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;
    defparam \AUX_ADD_CI__U2_McstDecode/U1_McstDelimit/sub_7/add_2/i1 .I0_POLARITY = 1'b1;
    defparam \AUX_ADD_CI__U2_McstDecode/U1_McstDelimit/sub_7/add_2/i1 .I1_POLARITY = 1'b1;
    EFX_LUT4 LUT__1622 (.I0(\U2_McstDecode/McstDataIn[4] ), .I1(\U2_McstDecode/McstDataIn[6] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n859)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1622.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1623 (.I0(\U2_McstDecode/McstDataIn[3] ), .I1(\U2_McstDecode/McstDataIn[5] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(n859), .O(n860)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1623.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__1624 (.I0(\U2_McstDecode/McstDataIn[15] ), .I1(\U2_McstDecode/McstDataIn[13] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(\U2_McstDecode/DelimitPos[1] ), 
            .O(n861)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h3f50 */ ;
    defparam LUT__1624.LUTMASK = 16'h3f50;
    EFX_LUT4 LUT__1625 (.I0(\U2_McstDecode/McstDataIn[14] ), .I1(\U2_McstDecode/McstDataIn[12] ), 
            .I2(\U2_McstDecode/DelimitPos[0] ), .I3(n861), .O(n862)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hf305 */ ;
    defparam LUT__1625.LUTMASK = 16'hf305;
    EFX_LUT4 LUT__1626 (.I0(\U1_RxFifo/FifoDataBuff[5] ), .I1(\U1_RxFifo/FifoDataBuff[15] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .O(n863)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1626.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1627 (.I0(\U1_RxFifo/FifoDataBuff[0] ), .I1(\U1_RxFifo/FifoDataBuff[10] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(n863), .O(n636)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1627.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__1628 (.I0(\U1_RxFifo/FifoDataBuff[6] ), .I1(\U1_RxFifo/FifoDataBuff[16] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .O(n864)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1628.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1629 (.I0(\U1_RxFifo/FifoDataBuff[1] ), .I1(\U1_RxFifo/FifoDataBuff[11] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(n864), .O(n673)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1629.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__1630 (.I0(\U1_RxFifo/FifoDataBuff[7] ), .I1(\U1_RxFifo/FifoDataBuff[17] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .O(n865)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1630.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1631 (.I0(\U1_RxFifo/FifoDataBuff[2] ), .I1(\U1_RxFifo/FifoDataBuff[12] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(n865), .O(n674)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1631.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__1632 (.I0(\U1_RxFifo/FifoDataBuff[8] ), .I1(\U1_RxFifo/FifoDataBuff[18] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .O(n866)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1632.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1633 (.I0(\U1_RxFifo/FifoDataBuff[3] ), .I1(\U1_RxFifo/FifoDataBuff[13] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(n866), .O(n675)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1633.LUTMASK = 16'hfc0a;
    EFX_LUT4 LUT__1634 (.I0(\U1_RxFifo/FifoDataBuff[9] ), .I1(\U1_RxFifo/FifoDataBuff[19] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(\U1_RxFifo/FifoRdAddrCnt[1] ), 
            .O(n867)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hcfa0 */ ;
    defparam LUT__1634.LUTMASK = 16'hcfa0;
    EFX_LUT4 LUT__1635 (.I0(\U1_RxFifo/FifoDataBuff[4] ), .I1(\U1_RxFifo/FifoDataBuff[14] ), 
            .I2(\U1_RxFifo/FifoRdAddrCnt[0] ), .I3(n867), .O(n676)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'hfc0a */ ;
    defparam LUT__1635.LUTMASK = 16'hfc0a;
    
endmodule

//
// Verific Verilog Description of module EFX_LUT40
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
// Verific Verilog Description of module EFX_FF60
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF61
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF62
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF63
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF64
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF65
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF66
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF67
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF68
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF69
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF70
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF71
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF72
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF73
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF74
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF75
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF76
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF77
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF78
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF79
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF80
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF81
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF82
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF83
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF84
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF85
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF86
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF87
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF88
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF89
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF90
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF91
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF92
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF93
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF94
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF95
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF96
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF97
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF98
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF99
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF100
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF101
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF102
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF103
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF104
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF105
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF106
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF107
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF108
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF109
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF110
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF111
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF112
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF113
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF114
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF115
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF116
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF117
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF118
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF119
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF120
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF121
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF122
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF123
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF124
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF125
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF126
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF127
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF128
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF129
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF130
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF131
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF132
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF133
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF134
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF135
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF136
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF137
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF138
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF139
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF140
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF141
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF142
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF143
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF144
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF145
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF146
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF147
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF148
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF149
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF150
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF151
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF152
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF153
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF154
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF155
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF156
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF157
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF158
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF159
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF160
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF161
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF162
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF163
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF164
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF165
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF166
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF167
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF168
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF169
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF170
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF171
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF172
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF173
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF174
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF175
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF176
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF177
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF178
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF179
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF180
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF181
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF182
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF183
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF184
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF185
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF186
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF187
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF188
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF189
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF190
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF191
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF192
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF193
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF194
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF195
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF196
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF197
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF198
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF199
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF200
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF201
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF202
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF203
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF204
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF205
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF206
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF207
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF208
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF209
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF210
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF211
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF212
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF213
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF214
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF215
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF216
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF217
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF218
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF219
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF220
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF221
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF222
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF223
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF224
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF225
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF226
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF227
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF228
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF229
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD0
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD1
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD2
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD3
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD4
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD5
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD6
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD7
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD8
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD9
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD10
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD11
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD12
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD13
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD14
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD15
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD16
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD17
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD18
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD19
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD20
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD21
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD22
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD23
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD24
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD25
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD26
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD27
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD28
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD29
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD30
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD31
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD32
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD33
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD34
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD35
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD36
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD37
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD38
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD39
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD40
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD41
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD42
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD43
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD44
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD45
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD46
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD47
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD48
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD49
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD50
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD51
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD52
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD53
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD54
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD55
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD56
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD57
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD58
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD59
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD60
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD61
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD62
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD63
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD64
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_RAM_5K_5_5_0
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_RAM_5K_10_10_1
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_RAM_5K_10_10_2
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT41
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


//
// Verific Verilog Description of module EFX_LUT437
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT438
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT439
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT440
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT441
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT442
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT443
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT444
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT445
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT446
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT447
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT448
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT449
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT450
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT451
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT452
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT453
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT454
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT455
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT456
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT457
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT458
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT459
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT460
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT461
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT462
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT463
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT464
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT465
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT466
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT467
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT468
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT469
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT470
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT471
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT472
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT473
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT474
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT475
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT476
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT477
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT478
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT479
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT480
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT481
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT482
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT483
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT484
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT485
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT486
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT487
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT488
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT489
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT490
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT491
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT492
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT493
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT494
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT495
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT496
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT497
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT498
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT499
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4100
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4101
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4102
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4103
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4104
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4105
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4106
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4107
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4108
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4109
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4110
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4111
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4112
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4113
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4114
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4115
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4116
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4117
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4118
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4119
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4120
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4121
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4122
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4123
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4124
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4125
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4126
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4127
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4128
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4129
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4130
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4131
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4132
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4133
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4134
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4135
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4136
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4137
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4138
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4139
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4140
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4141
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4142
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4143
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4144
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4145
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4146
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4147
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4148
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4149
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4150
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4151
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4152
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4153
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4154
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4155
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4156
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4157
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4158
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4159
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4160
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4161
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4162
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4163
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4164
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4165
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4166
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4167
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4168
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4169
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4170
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4171
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4172
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4173
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4174
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4175
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4176
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4177
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4178
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4179
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4180
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4181
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4182
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4183
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4184
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4185
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4186
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4187
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4188
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4189
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4190
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4191
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4192
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4193
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4194
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4195
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4196
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4197
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4198
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4199
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4200
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4201
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4202
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4203
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4204
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4205
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
// Verific Verilog Description of module EFX_ADD65
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD66
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4206
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4207
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4208
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4209
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4210
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4211
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4212
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4213
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4214
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4215
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4216
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4217
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4218
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4219
// module not written out since it is a black box. 
//

