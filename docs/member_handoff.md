# RAM and memory interface handoff

Prepared for Member 3, Dhruv Kumar, and Member 4, Ritesh.
This file is the reviewable handoff; no external message has been sent.

## Member 3: tag comparator

`way_tag_ram`: inputs `clk`, `we`, `set_idx[5:0]`, `wtag[21:0]`;
output `rtag[21:0]`. `rtag` is combinational: connect the two instances to
comparator inputs `way0_tag` and `way1_tag`. Tag = CPU address `[31:10]`.
Gate comparisons with valid bits: RAMs intentionally have no reset/initialization.
Writes occur on the rising edge when `we=1`.

## Member 4: controller and top level

| Module | Inputs | Outputs |
| --- | --- | --- |
| way_data_ram | clk, we, word_we[3:0], set_idx[5:0], wdata[127:0] | rdata[127:0] |
| way_tag_ram | clk, we, set_idx[5:0], wtag[21:0] | rtag[21:0] |
| mem_model | clk, rst_n, mem_addr[31:0], mem_re, mem_we, mem_wdata[127:0] | mem_rdata[127:0], mem_ready |

RAM parameters: `SETS=64`, `INDEX_W=6`; tag RAM also has `TAG_W=22`.
Instantiate each RAM twice. Both read asynchronously and write at posedge.
Data write requires `we` AND the corresponding word enable. Word 0 is `[31:0]`;
full fill uses `1111`. Top level derives `we` from OR of word enables.
Set index = address `[9:4]`. The existing valid/LRU/comparator modules have
fixed widths, so the integrated top level currently supports default dimensions.

Memory parameter: `LATENCY=6`, positive integer. Acceptance at rising edge N
produces ready at edge N+LATENCY, exactly one cycle wide. Address, direction,
and write data are latched at acceptance. Deassert request after acceptance;
busy and acknowledgement cycles do not accept requests. If both strobes are
high, write wins. Reset cancels an in-flight transaction and clears outputs,
but does not erase backing memory. Connect active-low reset before use.

4096 blocks cover byte addresses 0x00000000–0x0000ffff; low four bits ignored.
Out-of-range requests terminate simulation rather than aliasing. Initial block i
contains `{4{16'hA5A5, i[15:0]}}`. This is a simulation model, not synthesis RTL.

Compile the real `rtl/*.v` modules (the temporary submodule stubs have been removed).
Top-level connections now match both the specified RAM ports and the existing
Member 3 module ports. Run `make test` for focused verification.

## Personal commit ownership

Each teammate must configure their own Git name/email (an email linked to their
GitHub account), authenticate with their own account, and push their own branch.
Use `git config --local user.name "Your Name"`,
`git config --local user.email "your-verified-email"`, and `gh auth status`.
Review `git log --format='%h %an <%ae>'` before pushing. Open a pull request for
your own files. Never share credentials or set another member as author.
This work uses Yash Kumar's configured identity; other members must complete
and verify their own pushes. Existing history includes distinct contributor identities.
