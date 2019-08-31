/*
 * File: commit_stage.sv
 * Desc: retire the completed instructions
 *
 * Auth: QunanZhao
 * Date: Aug-29-2019
 */

module commit_stage (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* get the completed instruction from the issue stage */
    output  logic   commit_ack_o,
    input   tortoise_pkg::scoreboard_entry_t    instr_i,

    /* excepitons and csr operations are transferred to the CSR Unit. */
    output  logic   csr_valid_o,
    output  tortoise_pkg::exception_t   exception_o,

    /* register file signals */
    output  logic   reg_w_en_o,
    output  tortoise_pkg::sbreg_t       reg_w_no_o,
    output  riscv_pkg::data_t           reg_w_data_o,

    /* branch and jump results */
    output  logic   mispredict_o,
    output  tortoise_pkg::predict_t     predict_result_o,
);

    import  riscv_pkg::addr_t;
    import  riscv_pkg::data_t

    assign  exception_o = instr_i.ex;

    always_comb begin
        commit_ack_o    = 1'b0;
        csr_valid_o     = 1'b0;

        if (instr_i.ex.valid != 1'b0) begin: no_exception
            unique case (commit_instr_i.fu)
                FU_ALU: begin: commit_alu
                    reg_w_no_o      = instr_i.result.reg_no;
                    reg_w_en_o      = instr_i.result.valid;
                    reg_w_data_o    = instr_i.result.value;

                    commit_ack_o    = instr_i.result.valid;
                    /* handle branches and jumps */
                    mispredict_o        = 1'b0;
                    predict_result_o    = instr_i.predict;

                    unique case (instr_i.predict.instr_type)
                        PREDICT_TAKEN: begin    /* branch */
                            logic is_taken  = instr_i.result.value[0];

                            mispredict_o    =
                                (is_taken != instr_i.predict.is_taken);
                            predict_result_o.is_taken   = is_taken;
                        end
                        PREDICT_TARGET: begin   /* jalr */
                            addr_t target_addr  = instr_i.ex.tval;

                            mispredict_o        =
                                (target_addr != instr_i.predict.target_addr);
                            predict_result_o.target_addr    = target_addr;
                        end
                        default: /* NO_BRANCH, DIRECT_JUMP */;
                    endcase
                end: commit_alu
                FU_CSR: begin: commit_csr
                end: commit_csr
                FU_LOAD: begin: commit_load
                end: commit_load
                FU_STORE: begin: commit_store
                end: commit_store
            endcase
        end: no_exception
        else begin: with_exception
            commit_ack_o    = 1'b1;
            csr_valid_o     = 1'b1;     /* let CSR handle it */
        end: with_exception
    end
endmodule: commit_stage
