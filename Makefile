.PHONY: test test-submodules test-way test-valid-lru test-tag-comp test-memory test-dm test-2way test-compare test-writeback test-traces traces clean
IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
BUILD := sim/build

RTL_ALL := rtl/cache_2way_top.v rtl/cache_fsm.v rtl/way_data_ram.v rtl/way_tag_ram.v rtl/valid_bits.v rtl/lru_state.v rtl/tag_comparator.v

test: test-submodules test-memory test-dm test-2way test-compare test-writeback test-traces

$(BUILD):
	mkdir -p $@

traces:
	$(PYTHON) sim/gen_traces.py

test-submodules: test-way test-valid-lru test-tag-comp

test-way: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_way_ram -o $(BUILD)/way.vvp rtl/way_data_ram.v rtl/way_tag_ram.v tb/tb_way_ram.v
	$(VVP) $(BUILD)/way.vvp

test-valid-lru: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_valid_lru -o $(BUILD)/valid_lru.vvp rtl/valid_bits.v rtl/lru_state.v tb/tb_valid_lru.v
	$(VVP) $(BUILD)/valid_lru.vvp

test-tag-comp: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_tag_comparator -o $(BUILD)/tag_comp.vvp rtl/tag_comparator.v tb/tb_tag_comparator.v
	$(VVP) $(BUILD)/tag_comp.vvp

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

$(BUILD)/compare_trace.vvp: | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s tb_compare -o $@ rtl/direct_mapped_cache.v $(RTL_ALL) rtl/mem_model.v tb/tb_compare.v

test-traces: $(BUILD)/compare_trace.vvp
	@echo ">>> Running Benchmark: random.trc..."
	$(VVP) $(BUILD)/compare_trace.vvp +trace=sim/traces/random.trc +log_direct=sim/results_direct_random.log +log_2way=sim/results_2way_random.log
	@cp sim/results_direct_random.log sim/results_direct.log
	@cp sim/results_2way_random.log sim/results_2way.log
	@echo ">>> Running Benchmark: locality.trc..."
	$(VVP) $(BUILD)/compare_trace.vvp +trace=sim/traces/locality.trc +log_direct=sim/results_direct_locality.log +log_2way=sim/results_2way_locality.log
	@echo ">>> Running Benchmark: conflict.trc..."
	$(VVP) $(BUILD)/compare_trace.vvp +trace=sim/traces/conflict.trc +log_direct=sim/results_direct_conflict.log +log_2way=sim/results_2way_conflict.log

clean:
	rm -rf $(BUILD) *.vcd sim_*
