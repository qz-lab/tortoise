/*
 * File: decode_pkg.sv
 * Desc: decode functions for each type of OPCODE
 *
 * Auth: QuanZhao
 * Date: Aug-14-2019
 */


package decode_pkg;

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
    sbe.result      = '{1'b0, rd,  '0};     /* register */
    sbe.operand1    = '{1'b0, rs1, '0};     /* register */
    sbe.operand2    = '{1'b1, '0, imm};     /* immediate */

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

function automatic void decode_MISCMEM (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* MISCMEM instructions are I-Type, FENCE and FENCE.I for now. */
    logic [2:0] funct3  = instr.rem[14:12];

    sbe.fu          = FU_CSR;
    sbe.result      = '{1'b1, '0, '0};  /* directly commit */
    sbe.operand1    = '{1'b0, '0, '0};  /* never execute */
    sbe.operand2    = '{1'b0, '0, '0};  /* never execute */

    unique case (funct3)
        3'b000: sbe.op  = FENCE;
        3'b001: sbe.op  = FENCE_I;
        default: is_illegal = 1'b1;
    endcase

    /* incomplete */
    if ({instr.rem[31:15], instr.rem[11:7]} != '0)
        is_illegal = 1'b1;
endfunction: decode_MISCMEM

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
        3'b000: sbe.op  = ADD;
        3'b010: sbe.op  = SLTS;
        3'b011: sbe.op  = SLTU;
        3'b100: sbe.op  = XORL;
        3'b110: sbe.op  = ORL;
        3'b111: sbe.op  = ANDL;

        /* Here we support RV64I, not RV32I. */
        3'b001: begin
            if (instr.rem[31:26] == '0)
                sbe.op  = SLL;
            else
                is_illegal = 1'b1;
        end

        3'b101: begin
            if (instr.rem[31:26] == '0)
                sbe.op  = SRL;
            else if (instr.rem[31:26] == 6'b01_0000)
                sbe.op  = SRA;
            else
                is_illegal  = 1'b1;
            end
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OPIMM

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
        3'b000: sbe.op  = ADDW;
        3'b001: begin
            if (instr.rem[31:25] == '0)
                sbe.op  = SLLW;
            else
                is_illegal = 1'b1;
        end

        3'b101: begin
            if (instr.rem[31:25] == '0)
                sbe.op  = SRLW;
            else if (instr.rem[31:25] == 7'b010_0000)
                sbe.op  = SRAW;
            else
                is_illegal  = 1'b1;
        end
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OPIMM32

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
    sbe.result      = '{1'b0, '0,  '0}; /* no target register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b0, rs2, '0}; /* register */
    sbe.operand3    = '{1'b1, '0,  imm};/* immediate */

    unique case (funct3)
        3'b000: sbe.op  = SB;
        3'b001: sbe.op  = SH;
        3'b010: sbe.op  = SW;
        3'b011: sbe.op  = SD;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_STORE

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
        10'b000_0000000: sbe.op = ADD;
        10'b000_0100000: sbe.op = SUB;
        10'b001_0000000: sbe.op = SLL;
        10'b010_0000000: sbe.op = SLTS;
        10'b011_0000000: sbe.op = SLTU;
        10'b100_0000000: sbe.op = XORL;
        10'b101_0000000: sbe.op = SRL;
        10'b101_0100000: sbe.op = SRA;
        10'b110_0000000: sbe.op = ORL;
        10'b111_0000000: sbe.op = ANDL;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OP

function automatic void decode_LUI (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe
);
    /* LUI instruction is U-Type. */
    reg_t   rd      = instr.rem[11:7];
    data_t  imm     = u_imm(instr.rem);

    sbe.fu          = FU_NONE;          /* In fact, no FU is needed. */
    sbe.result      = '{1'b1, rd, imm}; /* the result is available */
    sbe.operand1    = '{1'b0, '0, '0};  /* not needed */
    sbe.operand2    = '{1'b0, '0, '0};  /* not needed */
    sbe.op          = ADD;
endfunction: decode_LUI

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
        10'b000_0000000: sbe.op = ADDW;
        10'b000_0100000: sbe.op = SUBW;
        10'b001_0000000: sbe.op = SLLW;
        10'b101_0000000: sbe.op = SRLW;
        10'b101_0100000: sbe.op = SRAW;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_OP32

function automatic void decode_BRANCH (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* BRANCH instructions are B-Type. */
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    reg_t       rs2     = instr.rem[24:20];
    /* Remember, the target address is calculated in IF and stored in the
     * prediction result. We don't need to do it again. */

    sbe.fu          = FU_BRANCH;
    sbe.result      = '{1'b0, '0,  '0}; /* the target register is PC */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b0, rs2, '0}; /* register */

    unique case (funct3)
        3'b000: sbe.op  = BEQ;
        3'b001: sbe.op  = BNE;
        3'b100: sbe.op  = BLTS;
        3'b101: sbe.op  = BGES;
        3'b110: sbe.op  = BLTU;
        3'b111: sbe.op  = BGEU;
        default: is_illegal = 1'b1;
    endcase
endfunction: decode_BRANCH

function automatic void decode_JALR (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal
);
    /* JALR instruction is I-Type. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    data_t      imm     = i_imm(instr.rem);

    sbe.fu          = FU_BRANCH;
    sbe.result      = '{1'b0, rd,  '0}; /* link register */
    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
    sbe.operand2    = '{1'b1, '0, imm}; /* immediate */
    if (funct3 == 3'b000)
        sbe.op      = JAL_R;
    else
        is_illegal  = 1'b1;
endfunction: decode_JALR

function automatic void decode_JAL (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,

    input   addr_t              pc
);
    /* JAL instruction is the only J-Type. */
    reg_t   rd      = instr.rem[11:7];
    addr_t  next_pc = addr_t'(pc + addr_t'(4));

    sbe.fu          = FU_BRANCH;
    sbe.result      = '{1'b1, rd, next_pc}; /* link register */
    /* Remember, the target address is calculated in IF and stored in the
     * prediction result. We don't need to do it again. */
    sbe.operand1    = '{1'b0, '0, '0};  /* not needed */
    sbe.operand2    = '{1'b0, '0, '0};  /* not needed */
    sbe.op          = ADD;
endfunction: decode_JAL

function automatic void decode_SYSTEM (
    input   instr_t             instr,
    ref     scoreboard_entry_t  sbe,
    ref     logic               is_illegal,

    input   priv_lvl_t          priv,
    input   logic               tsr, tw, tvm, debug_mode
);
    /* All CSR instructions are I-Type. We treat all other instructions as
     * R-Type even if they are not. */
    reg_t       rd      = instr.rem[11:7];
    logic [2:0] funct3  = instr.rem[14:12];
    reg_t       rs1     = instr.rem[19:15];
    reg_t       rs2     = instr.rem[24:20];
    logic [6:0] funct7  = instr.rem[31:25];
    /* Different from others, the immediate of CSR instructions are
     * zero-extended. */
    data_t      imm     = {{(RV_XLEN- 5){1'b0}}, instr.rem[19:15]};   /* rs1 */
    data_t      csr     = {{(RV_XLEN-12){1'b0}}, instr.rem[31:20]};

    unique case (funct3)
        3'b000: begin: decode_privilege_instructions
            /* ECALL, EBREAK, URET, SRET, MRET, WFI, SFENCE.VMA */
            sbe.fu          = FU_CSR;
            sbe.result      = '{1'b1, '0, '0};  /* directly commit */
            sbe.operand1    = '{1'b0, '0, '0};  /* not needed */
            sbe.operand2    = '{1'b0, '0, '0};  /* not needed */
            sbe.op          = ADD;

            unique case (funct7)
                7'b0000_000: begin  /* ECALL, EBREAK or URET */
                    if (rs2 == 5'b0 && rs1 == 5'b0 && rd == 5'b0)
                        /* ECALL */
                        unique case (priv)
                            PRIV_LVL_M: sbe.ex = '{1'b1, ENV_CALL_MMODE, '0};
                            PRIV_LVL_S: sbe.ex = '{1'b1, ENV_CALL_SMODE, '0};
                            PRIV_LVL_U: sbe.ex = '{1'b1, ENV_CALL_UMODE, '0};
                            default:;
                        endcase
                    else if (rs2 == 5'b0_0001 && rs1 == 5'b0 && rd == 5'b0)
                        /* EBREAK */
                        sbe.ex  = '{1'b1, BREAKPOINT, '0};
                    else if (rs2 == 5'b0_0010 && rs1 == 5'b0 && rd == 5'b0)
                        /* URET, not implemented */
                        is_illegal = 1'b1;
                    else
                        is_illegal = 1'b1;
                end

                7'b011_1101: begin  /* DRET: 0x7b200073 */
                    sbe.op      = DRET;
                    is_illegal  = 1'b1;
                    if (rs2 == 5'b10010 && rs1 == 5'b0 && rd == 5'b0)
                        if (debug_mode == 1'b1)
                            is_illegal = 1'b0;
                end

                7'b000_1000: begin  /* SRET or WFI */
                    is_illegal  = 1'b1;

                    if (rs2 == 5'b00010 && rs2 == 5'b0 && rd == 5'b0) begin
                        /* SRET */
                        sbe.op  = SRET;
                        if ((priv == PRIV_LVL_M) || (priv == PRIV_LVL_S && !tsr))
                            is_illegal  = 1'b0;
                    end

                    if (rs2 == 5'b00101 && rs2 == 5'b0 && rd == 5'b0) begin
                        /* WFI */
                        sbe.op  = WFI;
                        if ((priv == PRIV_LVL_M) || (priv == PRIV_LVL_S && !tw))
                            is_illegal  = 1'b0;
                    end
                end

                7'b001_1000: begin  /* MRET */
                    sbe.op    = MRET;
                    is_illegal  = 1'b1;
                    if (rs2 == 5'b00010 && rs1 == 5'b0 && rd == 5'b0)
                        if (priv == PRIV_LVL_M)
                            is_illegal  = 1'b0;
                end
                7'b000_1001: begin /* SFENCE.VMA */
                    sbe.op      = SFENCE_VMA;
                    is_illegal  = 1'b1;
                    /* we need to read the registers, so the result is not
                     * ready. */
                    sbe.result      = '{1'b0, '0,  '0}; /* no target register */
                    sbe.operand1    = '{1'b0, rs1, '0}; /* register */
                    sbe.operand2    = '{1'b0, rs2, '0}; /* register */

                    if (rd == 5'b0)
                        if ((priv == PRIV_LVL_M) || (priv == PRIV_LVL_S && !tvm))
                            is_illegal  = 1'b0;
                end

                default: is_illegal = 1'b1;
            endcase
        end: decode_privilege_instructions

        /* The remaining are CSR instructions. */
        3'b001: begin   /* CSRRW */
            sbe.result      = '{1'b0, rd,  '0}; /* read register */
            sbe.operand1    = '{1'b0, rs1, '0}; /* source register */
            sbe.operand2    = '{1'b1, '0, csr}; /* CSR address */
            sbe.op          = CSR_WRITE;
        end

        3'b010: begin   /* CSRRS */
            sbe.result      = '{1'b0, rd,  '0}; /* read register */
            sbe.operand1    = '{1'b0, rs1, '0}; /* mask register */
            sbe.operand2    = '{1'b1, '0, csr}; /* CSR address */
            if (rs1 == 5'b0)
                sbe.op      = CSR_READ;
            else
                sbe.op      = CSR_SET;
        end

        3'b011: begin   /* CSRRC */
            sbe.result      = '{1'b0, rd,  '0}; /* read register */
            sbe.operand1    = '{1'b0, rs1, '0}; /* mask register */
            sbe.operand2    = '{1'b1, '0, csr}; /* CSR address */
            if (rs1 == 5'b0)
                sbe.op      = CSR_READ;
            else
                sbe.op      = CSR_CLEAR;
        end

        3'b101: begin   /* CSRRWI */
            sbe.result      = '{1'b0, rd,  '0}; /* read register */
            sbe.operand1    = '{1'b1, '0, imm}; /* source value */
            sbe.operand2    = '{1'b1, '0, csr}; /* CSR address */
            sbe.op          = CSR_WRITE;
        end

        3'b110: begin   /* CSRRSI */
            sbe.result      = '{1'b0, rd,  '0}; /* read register */
            sbe.operand1    = '{1'b1, '0, imm}; /* mask value */
            sbe.operand2    = '{1'b1, '0, csr}; /* CSR address */
            if (imm == data_t'(0))
                sbe.op      = CSR_READ;
            else
                sbe.op      = CSR_SET;
        end

        3'b111: begin   /* CSRRCI */
            sbe.result      = '{1'b0, rd,  '0}; /* read register */
            sbe.operand1    = '{1'b1, '0, imm}; /* mask value */
            sbe.operand2    = '{1'b1, '0, csr}; /* CSR address */
            if (imm == data_t'(0))
                sbe.op      = CSR_READ;
            else
                sbe.op      = CSR_CLEAR;
        end

        default: is_illegal = 1'b1;
    endcase
endfunction: decode_SYSTEM

endpackage: decode_pkg
