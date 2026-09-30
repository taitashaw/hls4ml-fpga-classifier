open_vcd waveform_real.vcd
log_vcd [get_objects /apatb_myproject_top/AESL_inst_myproject/*]
run all
close_vcd
quit
