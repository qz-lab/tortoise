/*
 * File: id_miscmem.sv
 * Desc: decode the instructions for MISCMEM
 *
 * Auth: QuanZhao
 * Date: Aug-14-2019
 */

package id_miscmem

import riscv_pkg::*;
import tortoise_pkg::*;

function automatic void decode_MISCMEM (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* MISCMEM instructions are I-Type, FENCE and FENCE.I for now. */
    logic [2:0] funct3  = instr.rem[14:12];

    sbe.fu          = FU_CSR;
    sbe.result      = '{1'b0, '0, '0};  /* no target register */
    sbe.operand1    = '{1'b1, '0, '0};  /* not used */
    sbe.operand2    = '{1'b1, '0, '0};  /* not used */

    unique case (funct3)
        3'b000: sbe.op  = FENCE;
        3'b001: sbe.op  = FENCE_I;
        default: is_illegal = 1'b1;
    endcase

    /* incomplete */
    if ({instr.rem[31:15], instr.rem[11:7]} != '0)
        is_illegal = 1'b1;
endfunction: decode_MISCMEM

endpackage: id_miscmem
