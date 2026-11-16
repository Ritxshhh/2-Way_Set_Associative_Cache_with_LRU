.PHONY: test test-way test-memory test-dm test-2way test-compare test-writeback clean
IVERILOG ?= iverilog
VVP ?= vvp
BUILD := sim/build

RTL_ALL := rtl/cache_2way_top.v rtl/cache_fsm.v rtl/way_data_ram.v rtl/way_tag_ram.v rtl/valid_bits.v rtl/lru_state.v rtl/tag_comparator.v

test: test-way test-memory test-dm test-2way test-compare test-writeback

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

test-dm: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_direct_mapped_smoke -o $(BUILD)/dm_smoke.vvp rtl/direct_mapped_cache.v tb/tb_direct_mapped_smoke.v
	$(VVP) $(BUILD)/dm_smoke.vvp

test-2way: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_cache_2way_smoke -o $(BUILD)/2way_smoke.vvp $(RTL_ALL) tb/tb_cache_2way_smoke.v
	$(VVP) $(BUILD)/2way_smoke.vvp

test-compare: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_dm_vs_2way -o $(BUILD)/compare.vvp rtl/direct_mapped_cache.v $(RTL_ALL) rtl/mem_model.v tb/tb_dm_vs_2way.v
	$(VVP) $(BUILD)/compare.vvp

test-writeback: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_cache_2way_writeback -o $(BUILD)/writeback.vvp $(RTL_ALL) rtl/mem_model.v tb/tb_cache_2way_writeback.v
	$(VVP) $(BUILD)/writeback.vvp

clean:
	rm -rf $(BUILD) *.vcd sim_*
