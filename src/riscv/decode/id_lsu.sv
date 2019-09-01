/*
 * File: id_lsu.sv
 * Desc: decode the instructions for LOAD and STORE
 *
 * Auth: QuanZhao
 * Date: Aug-14-2019
 */

package id_lsu;

import riscv_pkg::*;
import tortoise_pkg::*;

function automatic void decode_LOAD (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* LOAD instructions are I-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    data_t      imm     = i_imm(instr.rem);

    sbe.fu          = FU_LOAD;
    sbe.result      = '{1'b0, rd,  '0};     /* target register */
    sbe.operand1    = '{1'b0, rs1, '0};     /* base register */
    sbe.operand2    = '{1'b1, '0, imm};     /* offset */

    unique case (funct3)
        3'b000: sbe.op  = LB;
        3'b001: sbe.op  = LH;
        3'b010: sbe.op  = LW;
        3'b100: sbe.op  = LBU;
        3'b101: sbe.op  = LHU;
        3'b110: sbe.op  = LWU;
        3'b011: sbe.op  = LD;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_LOAD

function automatic void decode_STORE (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* STORE instructions are S-Type. */
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    reg_t       rs2     = instr.rem[24:20];
    data_t      imm     = s_imm(instr.rem);

    sbe.fu          = FU_STORE;
    sbe.result      = '{1'b0, '0,  '0};     /* no target register */
    sbe.operand1    = '{1'b0, rs1, '0};     /* base register */
    sbe.operand2    = '{1'b0, rs2, '0};     /* data register */
    sbe.operand3    = '{1'b1, '0,  imm};    /* offset */

    unique case (funct3)
        3'b000: sbe.op  = SB;
        3'b001: sbe.op  = SH;
        3'b010: sbe.op  = SW;
        3'b011: sbe.op  = SD;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_STORE

endpackage: id_lsu
