# Real Vivado IP Integrator block design for the hls4ml classifier core,
# targeting this session's established hardware target: ZCU104 (ZU7EV).
# VLNVs and board_part confirmed live against this machine's IP catalog
# before writing this script (see check_ip_catalog.tcl output):
#   xilinx.com:ip:zynq_ultra_ps_e:3.5
#   xilinx.com:ip:axi_dma:7.1
#   xilinx.com:ip:smartconnect:1.0
#   board_part xilinx.com:zcu104:part0:1.1
# IP interface: the #pragma HLS INTERFACE axis port=input_1,layer9_out pragma only
# sets the two DATA ports' protocol. The real generated myproject_csynth.rpt "=="
# Interface ==" table (checked after synthesis, not assumed) shows the block-level
# control protocol defaulted to ap_ctrl_hs: ap_clk/ap_rst_n/ap_start(in)/
# ap_done,ap_ready,ap_idle(out) as plain handshake wires, no AXI-Lite/register
# interface. This is a free-running dataflow core with one extra input (ap_start)
# that must be tied off, not the zero-control-signal core assumed before checking.

create_project hls4ml_zcu104 ./vivado_prj -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

set_property ip_repo_paths [list ./my-hls-test/myproject_prj/solution1/impl/ip] [current_project]
update_ip_catalog

create_bd_design "hls4ml_system"

# Zynq UltraScale+ PS, ZCU104 board preset applied automatically via board_part
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]

# Enable the two PS HP slave ports the DMA masters need. Confirmed by direct
# query (check_ps_props.tcl), not guessed: the property namespace numbers these
# GP0-GP6 while the exposed interface pins are named HP0-HPx, and the mapping
# is NOT 1:1 by index -- GP2 is the property that yields S_AXI_HP0_FPD, GP3
# yields S_AXI_HP1_FPD. GP0/GP1 do not correspond to HP0/HP1.
set_property -dict [list \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__USE__S_AXI_GP3 {1} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
] [get_bd_cells zynq_ultra_ps_e_0]

# AXI DMA: MM2S feeds the classifier's input_1 stream, S2MM takes layer9_out back.
# Widths below are the IP's REAL stream widths, not assumed: the actual
# generated myproject_csynth.rpt "== Interface ==" table shows io_stream packs
# all 16 ap_fixed<16,6> inputs into ONE 256-bit input_1 beat, and all 5 outputs
# into one 80-bit layer9_out beat, not per-element narrow beats.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
  CONFIG.c_include_sg {0} \
  CONFIG.c_sg_include_stscntrl_strm {0} \
  CONFIG.c_m_axis_mm2s_tdata_width {256} \
  CONFIG.c_s_axis_s2mm_tdata_width {128} \
] [get_bd_cells axi_dma_0]

# The exported hls4ml IP itself
create_bd_cell -type ip -vlnv xilinx.com:hls:myproject:1.0 myproject_0

# 80 bits is not one of AXI DMA's legal widths (8/16/32/64/128/256/512/1024) --
# confirmed by running it and reading the real tool error ("Propagated TDATA
# WIDTH on S_AXIS_S2MM is not 8, 16, 32, ..."), not anticipated in advance.
# Pad layer9_out's 80 bits up to the DMA's 128-bit S2MM width with a real
# width converter rather than quietly picking a DMA width that happens not to
# trip the check.
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 layer9_out_dwidth
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {10} CONFIG.M_TDATA_NUM_BYTES {16} CONFIG.HAS_TLAST {1}] [get_bd_cells layer9_out_dwidth]

# Data path: DMA MM2S -> myproject -> width converter -> DMA S2MM
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins myproject_0/input_1]
connect_bd_intf_net [get_bd_intf_pins myproject_0/layer9_out] [get_bd_intf_pins layer9_out_dwidth/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins layer9_out_dwidth/M_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# ap_ctrl_hs: tie ap_start permanently high (free-running once fed by the
# stream), leave ap_done/ap_ready/ap_idle unconnected (observable in sim,
# not required for correct dataflow operation)
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 ap_start_tie
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {1}] [get_bd_cells ap_start_tie]
connect_bd_net [get_bd_pins ap_start_tie/dout] [get_bd_pins myproject_0/ap_start]

# Control path: PS AXI-Lite master -> DMA control/status registers
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
  Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_FPD} \
  Slave {/axi_dma_0/S_AXI_LITE} \
  intc_ip {Auto} master_apm {0} } [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

# Memory path: MM2S -> PS HP0, S2MM -> PS HP1 (separate HP ports rather than
# forcing both DMA masters through one port -- an earlier attempt merging both
# onto HP0 via two separate apply_bd_automation calls left a second, orphaned
# SmartConnect with no master connection; validate_bd_design caught it as
# "axi_smc_1 is missing a valid master Interface connection". Two independent
# HP ports each get their own clean, complete SmartConnect.)
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
  Master {/axi_dma_0/M_AXI_MM2S} \
  Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} \
  intc_ip {Auto} master_apm {0} } [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
  Master {/axi_dma_0/M_AXI_S2MM} \
  Slave {/zynq_ultra_ps_e_0/S_AXI_HP1_FPD} \
  intc_ip {Auto} master_apm {0} } [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]

# Clock the custom HLS IP: apply_bd_automation on its own ap_clk pin finds and
# wires the right existing PS clock net, the same auto-connect "Run Connection
# Automation" does in the GUI for a custom IP's clock pin -- more reliable than
# guessing the PS's output clock pin name and connect_bd_net'ing it by hand.
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {Auto} } [get_bd_pins myproject_0/ap_clk]
# clkrst automation refused layer9_out_dwidth/aclk outright (real error:
# "was not applied to object aclk") -- wire it directly to the same PS output
# clock net that automation already picked for ap_clk, instead of guessing why
# automation declined this particular IP's clock pin.
# (layer9_out_dwidth/aclk turned out to already be auto-connected to the PS
# clock net at cell-creation time -- confirmed by the real warning "all
# ports/pins are already connected to '/zynq_ultra_ps_e_0_pl_clk0'" when this
# script tried to connect it again. Vivado 2025.2 auto-wires a new IP's clock
# to an existing single-clock BD's net by default; nothing left to do here.)

# Interrupts, for host-side completion polling. Zynq UltraScale+'s PS (unlike
# Zynq-7000's separate pl_ps_irq0/pl_ps_irq1 scalar pins) exposes ONE pl_ps_irq0
# vector pin for all PL->PS interrupts -- confirmed by the "No pins matched
# 'pl_ps_irq1'" error from an initial attempt that assumed the Zynq-7000 shape.
# Concatenate the two interrupt sources into that vector with xlconcat.
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat
set_property -dict [list CONFIG.NUM_PORTS {2}] [get_bd_cells irq_concat]
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins irq_concat/In0]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins irq_concat/In1]
connect_bd_net [get_bd_pins irq_concat/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

validate_bd_design
save_bd_design

make_wrapper -files [get_files ./vivado_prj/hls4ml_zcu104.srcs/sources_1/bd/hls4ml_system/hls4ml_system.bd] -top
add_files -norecurse ./vivado_prj/hls4ml_zcu104.gen/sources_1/bd/hls4ml_system/hdl/hls4ml_system_wrapper.v
update_compile_order -fileset sources_1

puts "BLOCK_DESIGN_BUILD: complete"
