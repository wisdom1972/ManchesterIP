# ManchesterIP
 Trion FPGA ManchesterIP Solution based on LVDS interface


2019-10-2 V1.0  

===
正式发布的第一个版本
===

功能：

1- 提供系统时钟灵活的MII接口，可以很方便的和内部逻辑链接；  
2- 将MII转成串行数据，并经LVDS发送Manchester编码；  
3、接收Manchester编码的流，进行整形、滤波、定界、译码的算法，最后恢复出数据，并转成MII接口；
4、提取Manchester编码的时钟；时钟抖动小于20ns;  
5、测量接收时钟和本地时钟的误差，测量精度0.25ppm；  
6、精密的容错算法和码流跟踪算法，可达大于200ppm的频率偏差容限；（与信号质量有关）  

模块资源占用情况
===============================
- EFX_ADD         : 	183
- EFX_LUT4        : 	341
- EFX_FF          : 	388
- EFX_RAM_5K      : 	3
- EFX_GBUFCE      : 	4  
===============================

__Total resource__

676LEs  3BRAMs

模块性能：
```
Clock Name      Period (ns)   Frequency (MHz)   Edge
SysClk              6.270         159.496     (R-R)
TxMcstClk           4.275         233.920     (R-R)
RxMcstClk           7.546         132.512     (R-R)

```

> 较上个版本：  

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

```
EFX_ADD         : 	67
EFX_LUT4        : 	260
EFX_FF          : 	296
EFX_RAM_5K      : 	3
EFX_GBUFCE      : 	3
```
