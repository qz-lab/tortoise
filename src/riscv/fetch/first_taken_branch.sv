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
    parameter NR_INSTR  = tortoise_pkg::INSTR_PER_FETCH
) (
    input   tortoise_pkg::fetch_entry_t [NR_INSTR-1:0]  instrs_i,
    output  tortoise_pkg::fetch_entry_t [NR_INSTR-1:0]  instrs_o,
    output  logic               has_taken_branch, /* is there a taken branch */
    output  riscv_pkg::addr_t   target_addr
);

    logic [NR_INSTR-1:0]            is_taken;
    logic [$clog2(NR_INSTR)-1:0]    index_taken;
    logic no_taken;

    /* TODO: we could also treat exceptions as valid taken branches. */
    always_comb begin: collect_taken_info
        for (int k = 0; k < NR_INSTR; k++)
            is_taken[k] = instrs_i[k].predict.is_taken;
    end: collect_taken_info

    /* find the first taken branch */
    leading_zero_count #(.WIDTH (NR_INSTR)) find_branch (
        .data_i(is_taken), .count_o(index_taken), .allzero_o(no_taken)
    );

    assign has_taken_branch = ~no_taken;
    assign target_addr      = no_taken ?
        '0 : instrs_i[index_taken].predict.target_addr;

    /* only the instructions before the first taken-branch (including the
     * branch) are valid. */
    logic [NR_INSTR-1:0]    valid;
    assign valid            = no_taken ?
        '1 : ~({NR_INSTR{1'b1}} << (index_taken+1));

    always_comb begin
        for (int n = 0; n < NR_INSTR; n++) begin
            instrs_o[n] = instrs_i[n];
            instrs_o[n].valid   = valid[n];
        end
    end

endmodule: first_taken_branch
