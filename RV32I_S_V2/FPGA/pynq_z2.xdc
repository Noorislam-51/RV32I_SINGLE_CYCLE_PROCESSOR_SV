# pynq_xdc_v3.txt - complete constraints for riscv_pynq_top_v2.sv (PYNQ-Z2)
# Rename to .xdc before adding to Vivado.
# Use this as your ONLY .xdc, or copy just the two uart_rx_pin lines into your
# existing file. Do not keep two copies of the same constraints: duplicates
# give warnings or errors.
#
# Pin sources:
#   Pmod JA1 = Y18, GND = Pmod pin 5 (or 11), 3V3 = pin 6 (or 12)
#       -> PYNQ-Z2 Reference Manual v1.0, Table 13
#   clk H16, sw M20/M19, btn D19, LEDs R14/P14/N16/M14
#       -> a PYNQ-Z2-named XDC, and the pin comments in your own wrapper

# 125 MHz system clock
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports clk_125mhz]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports clk_125mhz]

# Reset = BTN0 (reads 1 when pressed)
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports btn0]

# Slide switches SW0, SW1 (LED nibble select)
set_property -dict { PACKAGE_PIN M20 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]

# LEDs
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

# UART RX = Pmod JA pin 1. Bridge TX goes here; bridge GND goes to Pmod JA pin 5.
# Pull-up keeps the line idle-high when the bridge is unplugged.
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 PULLUP true } [get_ports uart_rx_pin]

# Asynchronous inputs (RX is synchronized inside uart_rx; button/switches are slow)
set_false_path -from [get_ports {uart_rx_pin btn0 sw[*]}]