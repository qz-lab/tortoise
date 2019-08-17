/*
 * File: branch_scan.sv
 * Desc: scan the branch and jump instructions early in the IF stage
 *
 * Auth: QuanZhao
 * Date: Aug-04-2019
 *
 * We need to scan the branch (conditional) and jump (unconditional)
 * instructions and determine whether the branch is taken and where is the
 * target address early in the fetch stage, in order to mitigate the penalty of
 * misfetching caused by control flow.
 */

module branch_scan #(
    parameter NR_INSTR = tortoise_pkg::INSTR_PER_FETCH
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* fallback signals to update the prediction history */
    input   logic               fb_valid_i, fb_branch_taken_i,
    input   riscv_pkg::addr_t   fb_branch_pc_i, fb_target_addr_i,
    input   tortoise_pkg::predict_t fb_type_i,

    /* the instructions and their pc values to scan */
    input   riscv_pkg::addr_t   [NR_INSTR-1:0]  branch_pc_i,
    input   riscv_pkg::instr_t  [NR_INSTR-1:0]  instr_i,

    output  tortoise_pkg::sbe_predict_t [NR_INSTR-1:0]  sbe_predict_o
);

/*  TODO: add return-address-stack support
    output  logic   is_branch_o, is_jalr_o, is_jal_o, is_call_o, is_return_o

    assign  is_branch_o = (instr_i.opcode == riscv_pkg::BRANCH);
    assign  is_jalr_o   = (instr_i.opcode == riscv_pkg::JALR);
    assign  is_jal_o    = (instr_i.opcode == riscv_pkg::JAL);

    x1 and x5 are used as the link and the alternative-link registers.
    assign  is_call_o   = (is_jalr_o | is_jal_o) & ((rd == 1) | (rd == 5));
    assign  is_return_o = is_jalr_o & (rs1 == 1 | rs1 == 5) & (rs1 != rd);
*/

    import riscv_pkg::*;
    import tortoise_pkg::*;

    /* Fallbacks are used to update either bht or btb. */
    logic update_bht, update_btb;
    assign update_bht = fb_valid_i & (fb_type_i == PREDICT_TAKEN);
    assign update_btb = fb_valid_i & (fb_type_i == PREDICT_TARGET);

    /* the results of prediction */
    logic   [NR_INSTR-1:0]  bht_valid, btb_valid, bht_taken;
    addr_t  [NR_INSTR-1:0]  btb_target;

    branch_history_table #(
        .NR_LOOKUP (NR_INSTR)
    ) bht (
        /* update */
        .clk_i, .rst_ni, .flush_i, .debug_mode_i,
        .fb_valid_i(update_bht), .fb_branch_pc_i, .fb_branch_taken_i,
        /* lookup */
        .branch_pc_i, .predict_valid_o(bht_valid), .predict_taken_o(bht_taken)
    );

    branch_target_buffer #(
        .NR_LOOKUP (NR_INSTR)
    ) btb (
        /* update */
        .clk_i, .rst_ni, .flush_i, .debug_mode_i,
        .fb_valid_i(update_btb), .fb_branch_pc_i, .fb_target_addr_i,
        /* lookup */
        .branch_pc_i, .predict_valid_o(btb_valid), .predict_target_o(btb_target)
    );

    /* generate an entry of prediction for each input instruction */
    always_comb begin: scan_each_instr
        for (int i = 0; i < NR_INSTR; i++) begin
            reg_t   rs1 /*, rd */;
            data_t  immediate;

            /* rd  = instr_i[i].rem[11:7]; */

            unique case (instr_i[i].opcode)
                BRANCH: begin: predict_taken_or_not
                    immediate = b_imm(instr_i[i].rem);  /* B-Type */
                    /* we need to update bht when commit */
                    sbe_predict_o[i].instr_type = PREDICT_TAKEN;
                    sbe_predict_o[i].target_addr    =
                        branch_pc_i[i] + addr_t'(immediate); /* PC relative */
                    if (bht_valid[i]) begin
                        sbe_predict_o[i].is_taken   = bht_taken[i];
                    end else begin
                        /* if no prediction, jumping backwards is preferred */
                        sbe_predict_o[i].is_taken   =
                            immediate[$bits(data_t)-1] ? 1'b1 : 1'b0;
                    end
                end: predict_taken_or_not

                JALR: begin: predict_target_address
                    immediate = i_imm(instr_i[i].rem);  /* I-Type */
                    /* we need to update btb when commit */
                    sbe_predict_o[i].instr_type = PREDICT_TARGET;
                    if (btb_valid[i]) begin
                        sbe_predict_o[i].is_taken       = 1'b1; /* jump */
                        sbe_predict_o[i].target_addr    = btb_target[i];
                    end else begin
                        rs1 = instr_i[i].rem[19:15];
                        if (rs1 == reg_t'(0)) begin
                            /* sbe_predict_o[i].instr_type = DIRECT_JUMP; */
                            sbe_predict_o[i].is_taken   = 1'b1;
                            sbe_predict_o[i].target_addr= addr_t'(immediate);
                        end else begin
                            /* It is a jump but we can not predict the target
                            * address, so let it execute sequentially :-( */
                            sbe_predict_o[i].is_taken   = 1'b0;
                            sbe_predict_o[i].target_addr= addr_t'(0);
                        end
                    end
                end: predict_target_address

                JAL: begin: direct_jump
                    immediate = j_imm(instr_i[i].rem);  /* J-Type */
                    sbe_predict_o[i].instr_type = DIRECT_JUMP;
                    sbe_predict_o[i].is_taken   = 1'b1;
                    sbe_predict_o[i].target_addr=
                        branch_pc_i[i] + addr_t'(immediate); /* PC relative */
                end: direct_jump

                default: begin: neither_branch_nor_jump
                    sbe_predict_o[i].instr_type = NO_BRANCH;
                    sbe_predict_o[i].is_taken   = 1'b0;
                    sbe_predict_o[i].target_addr= addr_t'(0);
                end: neither_branch_nor_jump
            endcase
        end
    end: scan_each_instr

endmodule: branch_scan
