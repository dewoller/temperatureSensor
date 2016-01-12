#!/bin/bash
DIR="/code/temperature"
FILE="${DIR}/temps_vmc.rrd"
echo "Creating rrdtool DB for 9 temp sensors"
#   48 hours (2 days)   of 5 minutes data  : (1:576)
#  336 hours (2 weeks)  of 30 minutes data : (6:672)
# 1488 hours (2 months) of 2 hours data    : (24:744)
#  730 days  (~2 years) of 12 hours data   : (144:1460)
# 1830 days  (~5 years) of 24 hours data   : (288:1830)
rrdtool create $FILE \
	--step 300 \
	DS:Basement1:GAUGE:600:-50:60 \
	DS:Basement2:GAUGE:600:-50:60 \
	DS:Basement3:GAUGE:600:-50:60 \
	DS:Basement4:GAUGE:600:-50:60 \
	DS:Basement5:GAUGE:600:-50:60 \
	DS:Basement6:GAUGE:600:-50:60 \
	DS:Basement7:GAUGE:600:-50:60 \
	DS:Basement8:GAUGE:600:-50:60 \
	DS:Basement9:GAUGE:600:-50:60 \
	RRA:AVERAGE:0.5:1:576 \
	RRA:AVERAGE:0.5:6:672 \
	RRA:AVERAGE:0.5:24:744 \
	RRA:AVERAGE:0.5:144:1460 \
	RRA:AVERAGE:0.5:288:1830 \
	RRA:MAX:0.5:1:576 \
	RRA:MAX:0.5:6:672 \
	RRA:MAX:0.5:24:744 \
	RRA:MAX:0.5:144:1460 \
	RRA:MAX:0.5:288:1830 \
	RRA:MIN:0.5:1:576 \
	RRA:MIN:0.5:6:672 \
	RRA:MIN:0.5:24:744 \
	RRA:MIN:0.5:144:1460 \
	RRA:MIN:0.5:288:1830
