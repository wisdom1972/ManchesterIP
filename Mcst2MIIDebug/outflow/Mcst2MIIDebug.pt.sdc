
# Efinity Interface Designer SDC
# Version: 2019.3.272
# Date: 2020-02-01 21:48

# Copyright (C) 2017 - 2019 Efinix Inc. All rights reserved.

# Device: T20F256
# Project: Mcst2MIIDebug
# Timing Model: C4 (final)

# PLL Constraints
#################
create_clock -period 10.00 TxMcstClk
create_clock -waveform {0.62 1.88} -period 2.50 TxMcstSClk
create_clock -period 10.00 TxSysClk
create_clock -period 7.50 SysClk
create_clock -period 10.00 DPllRefClk
create_clock -waveform {0.62 1.88} -period 2.50 LvdsTxClk
create_clock -period 9.70 TxMcstClkA
create_clock -period 9.70 TxMcstSClkA
create_clock -period 9.70 TxSysClkA
create_clock -waveform {0.62 1.88} -period 2.50 RxMcstSClk
create_clock -period 80.00 RxTestClk
create_clock -period 10.00 RxMcstClk

# GPIO Constraints
####################
create_clock -period <USER_PERIOD> [get_ports {Clk50MIn}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[0]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[0]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[1]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[1]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[2]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[2]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[3]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[3]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[4]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[4]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[5]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[5]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[6]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[6]}]
# set_output_delay -clock <CLOCK> -max <MAX CALCULATION> [get_ports {LED[7]}]
# set_output_delay -clock <CLOCK> -min <MIN CALCULATION> [get_ports {LED[7]}]

# LVDS Rx Constraints
####################
set_input_delay -clock RxMcstClk -max 5.095 [get_ports {RxMcstData[7] RxMcstData[6] RxMcstData[5] RxMcstData[4] RxMcstData[3] RxMcstData[2] RxMcstData[1] RxMcstData[0]}]
set_input_delay -clock RxMcstClk -min 2.548 [get_ports {RxMcstData[7] RxMcstData[6] RxMcstData[5] RxMcstData[4] RxMcstData[3] RxMcstData[2] RxMcstData[1] RxMcstData[0]}]

# LVDS Tx Constraints
####################
set_output_delay -clock DPllRefClk -max -4.030 [get_ports {DPllLvdsClk[7] DPllLvdsClk[6] DPllLvdsClk[5] DPllLvdsClk[4] DPllLvdsClk[3] DPllLvdsClk[2] DPllLvdsClk[1] DPllLvdsClk[0]}]
set_output_delay -clock DPllRefClk -min -1.975 [get_ports {DPllLvdsClk[7] DPllLvdsClk[6] DPllLvdsClk[5] DPllLvdsClk[4] DPllLvdsClk[3] DPllLvdsClk[2] DPllLvdsClk[1] DPllLvdsClk[0]}]
set_output_delay -clock TxMcstClk -max -4.030 [get_ports {TxMcstData[7] TxMcstData[6] TxMcstData[5] TxMcstData[4] TxMcstData[3] TxMcstData[2] TxMcstData[1] TxMcstData[0]}]
set_output_delay -clock TxMcstClk -min -1.975 [get_ports {TxMcstData[7] TxMcstData[6] TxMcstData[5] TxMcstData[4] TxMcstData[3] TxMcstData[2] TxMcstData[1] TxMcstData[0]}]

# JTAG Constraints
####################
# create_clock -period <USER_PERIOD> [get_ports {jtag_inst1_TCK}]
# create_clock -period <USER_PERIOD> [get_ports {jtag_inst1_DRCK}]
set_output_delay -clock jtag_inst1_TCK -max 0.111 [get_ports {jtag_inst1_TDO}]
set_output_delay -clock jtag_inst1_TCK -min 0.053 [get_ports {jtag_inst1_TDO}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 0.267 [get_ports {jtag_inst1_CAPTURE}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0.134 [get_ports {jtag_inst1_CAPTURE}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 0.267 [get_ports {jtag_inst1_RESET}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0.134 [get_ports {jtag_inst1_RESET}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 0.267 [get_ports {jtag_inst1_RUNTEST}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0.134 [get_ports {jtag_inst1_RUNTEST}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 0.231 [get_ports {jtag_inst1_SEL}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0.116 [get_ports {jtag_inst1_SEL}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 0.267 [get_ports {jtag_inst1_UPDATE}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0.134 [get_ports {jtag_inst1_UPDATE}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 0.321 [get_ports {jtag_inst1_SHIFT}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0.161 [get_ports {jtag_inst1_SHIFT}]
