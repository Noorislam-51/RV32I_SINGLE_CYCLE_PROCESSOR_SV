# ==============================================================================
# PYNQ-Z2 Board Constraints File (XDC)
# Target Device: XC7Z020CLG400-1
# ==============================================================================

# ------------------------------------------------------------------------------
# 125 MHz PL Clock
# ------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports {clk_125mhz}]
create_clock -name sys_clk -period 8.000 [get_ports {clk_125mhz}]

# ------------------------------------------------------------------------------
# Reset Button (BTN0 - Active-High)
# ------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {btn0}]
set_false_path -from [get_ports {btn0}]

# ------------------------------------------------------------------------------
# Slide Switches (SW0 and SW1)
# ------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]

# ------------------------------------------------------------------------------
# User LEDs (LD0 to LD3)
# ------------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]