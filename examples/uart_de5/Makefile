FPGAMAKEDIR?=$(realpath ../..)
sim_top= DutTop.bsv
bsv_files= ${sim_top} ${sim_rest}
v_rules = ${bsv_files:%.bsv=mk%V}

special_compile_flags := -reset-prefix RST_P -D BSV_POSITIVE_RESET
PSEARCH ?= :+

all: synth

BLD     = $(realpath .)/de5
v_dir  ?= ${BLD}/source
bo_dir ?= ${BLD}/bo
i_dir  ?= ${BLD}/info

# Transformation Rules
mk%V: %.bsv
	@mkdir -p ${BLD} ${v_dir} ${bo_dir} ${i_dir}
	/usr/bin/time bsc -u -verilog -elab ${special_compile_flags} \
	-bdir ${bo_dir} -vdir ${v_dir} -info-dir ${i_dir} -p ${PSEARCH} -no-show-method-conf \
	-show-schedule -show-compiles -aggressive-conditions -keep-fires -no-inline-rwire   \
	-remove-dollar -show-range-conflict -scheduler-effort 500 $<

# Bluespec compile
synth: ${v_rules}

# Hierarchical design flow
.PHONY: fpgamake
fpgamake: ${BLD}/fpgamake.mk
${BLD}/fpgamake.mk: synth
	cd ${BLD} && $(FPGAMAKEDIR)/fpgamake \
	--board=de5 --part='5SGXEA7N2F45C2' -b mkDutTop.sof \
	-o ${BLD}/fpgamake.mk -t mkDutTop \
	-D BSV_POSITIVE_RESET=1 \
	-s mkUartRx \
	--floorplan= --implconstraint=${PWD}/uart_led.sdc --tcl=${PWD}/uart_led.qsf \
	${v_dir} ${BLUESPECDIR}/Verilog

build: ${BLD}/fpgamake.mk
	cd ${BLD} && make -f fpgamake.mk

# Gui based flow
quartus:
	mkdir -p ${BLD}/quartus
	cd ${BLD}/quartus && quartus &

clean_quartus:
	rm -rf ${BLD}/quartus

dump:
	@echo ${v_rules}

clean:
	rm -rf ${BLD}

altera_build:
	quartus_sh -t build.tcl
