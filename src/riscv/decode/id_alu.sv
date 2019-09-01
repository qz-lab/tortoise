/*
 * File: id_alu.sv
 * Desc: decode the instructions for ALU
 *
 * Auth: QuanZhao
 * Date: Aug-27-2019
 *
 * The op-codes handled by ALU include OP, OPIMM, OP32, OPIMM32, LUI, AUIPC and
 * BRANCH, JAL, JALR.
 */

package id_alu;

import riscv_pkg::*;
import tortoise_pkg::*;

/*
 * OP, OPIMM, OP32 and OPIMM32 operations are similar, we do addition, logic and
 * shifte calculations on 2 operands.
 */
function automatic void decode_OP (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* OP instructions are R-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    reg_t       rs2     = instr.rem[24:20];
    logic [6:0] funct7  = instr.rem[31:25];

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, rd,  '0}; /* register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b0, rs2, '0}; /* register */

    unique case ({funct3, funct7})
        10'b000_0000000: sbe.op = ADD;      /* ADD  */
        10'b000_0100000: sbe.op = SUB;      /* SUB  */
        10'b001_0000000: sbe.op = SLL;      /* SLL  */
        10'b010_0000000: sbe.op = CMP_LTS;  /* SLT  */
        10'b011_0000000: sbe.op = CMP_LTU;  /* SLTU */
        10'b100_0000000: sbe.op = XORL;     /* XOR  */
        10'b101_0000000: sbe.op = SRL;      /* SRL  */
        10'b101_0100000: sbe.op = SRA;      /* SRA  */
        10'b110_0000000: sbe.op = ORL;      /* OR   */
        10'b111_0000000: sbe.op = ANDL;     /* AND  */
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OP

function automatic void decode_OPIMM (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* OPIMM instructions are I-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    data_t      imm     = i_imm(instr.rem);

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, rd,  '0}; /* register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b1, '0,  imm};/* immediate */

    unique case (funct3)
        3'b000: sbe.op  = ADD;      /* ADDI */
        3'b010: sbe.op  = CMP_LTS;  /* SLTI */
        3'b011: sbe.op  = CMP_LTU;  /* SLTIU */
        3'b100: sbe.op  = XORL;     /* XORI */
        3'b110: sbe.op  = ORL;      /* ORI  */
        3'b111: sbe.op  = ANDL;     /* ANDI */

        /* Here we support RV64I, not RV32I. */
        3'b001: begin
            if (instr.rem[31:26] == '0)
                sbe.op  = SLL;      /* SLLI */
            else
                is_illegal = 1'b1;
        end

        3'b101: begin
            if (instr.rem[31:26] == '0)
                sbe.op  = SRL;      /* SRLI */
            else if (instr.rem[31:26] == 6'b01_0000)
                sbe.op  = SRA;      /* SRAI */
            else
                is_illegal  = 1'b1;
            end
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OPIMM

function automatic void decode_OP32 (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* OP32 instructions are R-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    reg_t       rs2     = instr.rem[24:20];
    logic [6:0] funct7  = instr.rem[31:25];

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, rd,  '0}; /* register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b0, rs2, '0}; /* register */

    unique case ({funct3, funct7})
        10'b000_0000000: sbe.op = ADDW; /* ADDW */
        10'b000_0100000: sbe.op = SUBW; /* SUBW */
        10'b001_0000000: sbe.op = SLLW; /* SLLW */
        10'b101_0000000: sbe.op = SRLW; /* SRLW */
        10'b101_0100000: sbe.op = SRAW; /* SRAW */
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OP32

function automatic void decode_OPIMM32 (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* OPIMM32 instructions are I-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    data_t      imm     = i_imm(instr.rem);

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, rd,  '0}; /* register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b1, '0,  imm};/* immediate */

    unique case (funct3)
        3'b000: sbe.op  = ADDW;     /* ADDIW */
        3'b001: begin
            if (instr.rem[31:25] == '0)
                sbe.op  = SLLW;     /* SLLIW */
            else
                is_illegal = 1'b1;
        end

        3'b101: begin
            if (instr.rem[31:25] == '0)
                sbe.op  = SRLW;     /* SRLIW */
            else if (instr.rem[31:25] == 7'b010_0000)
                sbe.op  = SRAW;     /* SRAIW */
            else
                is_illegal  = 1'b1;
        end
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OPIMM32

/*
 * The op-code LUI is special, which doesn't need any operands and the result
 * value is encoded in the instruction as the immediate.
 */
function automatic void decode_LUI (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe
);
    /* LUI instruction is U-Type. */
    reg_t   rd      = instr.rem[11:7];
    data_t  imm     = u_imm(instr.rem);

    sbe.fu          = FU_NONE;          /* In fact, no FU is needed. */
    sbe.result      = '{1'b1, rd, imm}; /* the result is available */
    sbe.operand1    = '{1'b0, '0, '0};  /* no execution */
    sbe.operand2    = '{1'b0, '0, '0};  /* no execution */
    sbe.op          = ADD;              /* no operation is performed */
endfunction: decode_LUI

/*
 * The 2 operands for AUIPC is PC and the immediate encoded in the instruction.
 */
function automatic void decode_AUIPC(
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,

    input   addr_t              pc
);
    /* AUIPC instruction is U-Type. */
    reg_t       rd      = instr.rem[11:7];
    data_t      imm     = u_imm(instr.rem);

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, rd, '0};  /* register */
    sbe.operand1    = '{1'b1, '0, pc};  /* immediate */
    sbe.operand2    = '{1'b1, '0, imm}; /* immediate */
    sbe.op          = ADD;
endfunction: decode_AUIPC

/*
 * For the op-code BRANCH, the target address has already been calculated in the
 * fetch stage and stored as the prediction result. We only need to judge
 * whether the branch is taken here.
 */
function automatic void decode_BRANCH (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* BRANCH instructions are B-Type. */
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    reg_t       rs2     = instr.rem[24:20];

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, '0,  '0}; /* only the compare result matters */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b0, rs2, '0}; /* register */

    unique case (funct3)
        3'b000: sbe.op  = CMP_EQ;
        3'b001: sbe.op  = CMP_NE;
        3'b100: sbe.op  = CMP_LTS;
        3'b101: sbe.op  = CMP_GES;
        3'b110: sbe.op  = CMP_LTU;
        3'b111: sbe.op  = CMP_GEU;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_BRANCH

/*
 * JALR is special, since it changes PC as well as returns the link address. We
 * nedd to calculate the target PC and the link address at the same time in the
 * ALU. The target PC is then stored in 'operand1'.
 * We should not calcuate the link address here, which prevents the execution of
 * this instruction.
 */
function automatic void decode_JALR (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal,

    input   addr_t              pc
);
    /* JALR instruction is I-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    data_t      imm     = i_imm(instr.rem);
    addr_t      next_pc = addr_t'(pc + addr_t'(4));

    sbe.fu          = FU_ALU;
    sbe.result      = '{1'b0, rd,  '0}; /* link register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b1, '0, imm}; /* immediate */
    sbe.operand3    = '{1'b1, '0, next_pc}; /* operands is only used here. */
    if (funct3 == 3'b000)
        sbe.op      = JAL_R;            /* so special */
    else
        is_illegal  = 1'b1;
endfunction: decode_JALR

/*
 * JAL is special. We also don't need to calculate the target address since it
 * has been calculated in the fetch stage and stored as the prediction result.
 * Therefore, we get the target address here so that it doesn't need to go
 * through the ALU.
 */
function automatic void decode_JAL (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,

    input   addr_t              pc
);
    /* JAL instruction is the only J-Type. */
    reg_t   rd      = instr.rem[11:7];
    addr_t  next_pc = addr_t'(pc + addr_t'(4));

    sbe.fu          = FU_NONE;
    sbe.result      = '{1'b1, rd, next_pc}; /* link register */
    sbe.operand1    = '{1'b0, '0, '0};      /* no execution */
    sbe.operand2    = '{1'b0, '0, '0};      /* no execution */
    sbe.op          = ADD;
endfunction: decode_JAL

endpackage: id_alu
