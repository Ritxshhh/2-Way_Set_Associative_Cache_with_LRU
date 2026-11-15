.PHONY: test test-way test-memory clean
IVERILOG ?= iverilog
VVP ?= vvp
BUILD := sim/build

test: test-way test-memory

$(BUILD):
	mkdir -p $@

test-way: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_way_ram -o $(BUILD)/way.vvp rtl/way_data_ram.v rtl/way_tag_ram.v tb/tb_way_ram.v
	$(VVP) $(BUILD)/way.vvp

test-memory: | $(BUILD)
	@set -e; for latency in 6 1 3; do \
	  $(IVERILOG) -g2012 -Wall -s tb_mem_model -Ptb_mem_model.LATENCY=$$latency -o $(BUILD)/memory.vvp rtl/mem_model.v tb/tb_mem_model.v; \
	  $(VVP) $(BUILD)/memory.vvp; \
	done

clean:
	rm -rf $(BUILD)
