/*
 * File: first_taken_branch.sv
 * Desc: find the first taken-branch instruction from each fetch
 *
 * Auth: QuanZhao
 * Date: Aug-12-2019
 *
 * The instructions following the first taken branch should not be executed, so
 * we filter out them here and output the target address.
 */

module first_taken_branch #(
    parameter NR_INSTRS = tortoise_pkg::INSTR_PER_FETCH
) (
    input   tortoise_pkg::fetch_entry_t [NR_INSTRS-1:0] instrs_i,
    output  tortoise_pkg::fetch_entry_t [NR_INSTRS-1:0] instrs_o,
    output  logic               has_taken_branch_o,/* is there a taken branch */
    output  riscv_pkg::addr_t   target_addr_o
);

    logic [NR_INSTRS-1:0]           is_taken;
    logic [$clog2(NR_INSTRS)-1:0]   taken_index;

    /* TODO: we could also treat exceptions as valid taken branches. */
    always_comb begin: collect_taken_info
        for (int k = 0; k < NR_INSTRS; k++)
            is_taken[k] = instrs_i[k].predict.is_taken;
    end: collect_taken_info

    /* find the first taken branch */
    leading_zero_count #(
        .WIDTH (NR_INSTRS)
    ) find_branch (
        .data_i(is_taken), .count_o(taken_index),
        .not_all_zero_o(has_taken_branch_o)
    );

    assign target_addr_o    = has_taken_branch_o ?
        instrs_i[taken_index].predict.target_addr : '0;

    /* only the instructions before the first taken-branch (including the
     * branch) are valid. */
    always_comb begin
        for (int n = 0; n < NR_INSTRS; n++) begin
            instrs_o[n]         = instrs_i[n];
            instrs_o[n].valid   =
                ~(has_taken_branch_o & $clog2(NR_INSTRS)'(n) > taken_index);
        end
    end

endmodule: first_taken_branch
