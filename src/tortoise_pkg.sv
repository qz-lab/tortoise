/*
 * File: tortoise_pkg.sv
 * Desc: common declarations of the platform with implementaion details
 *
 * Auth: QuanZhao
 * Date: Aug-04-2019
 *
 * We try to include all the platform-specific implementaion details here.
 * Poeple who wants to adjust them should modify the user configuration file
 * instead.
 */

`include "sysconfig.svh"

package tortoise_pkg;

import  riscv_pkg::*;

parameter   INSTR_PER_FETCH = `CONFIG_INSTR_PER_FETCH;

/* prediction */
parameter   RAS_DEPTH   = `CONFIG_RAS_DEPTH;
parameter   BHT_ENTRIES = `CONFIG_BHT_ENTRIES;
parameter   BTB_ENTRIES = `CONFIG_BTB_ENTRIES;

/* indicate how to update the branch history information */
typedef enum logic [2:0] {
    NO_BRANCH,      /* not a branch or jump instruction, no need to update */
    DIRECT_JUMP,    /* jump to a known address, no need to update */
    PREDICT_TAKEN,  /* predict whether the branch is taken, need to update */
    PREDICT_TARGET  /* predict the target address, might need to update */
} predict_t;

typedef struct packed {
    logic       valid;
    ex_cause_t  cause;
    ex_tval_t   tval;
} exception_t;

/* fetched instruction */
typedef struct packed {
    predict_t   instr_type;
    logic       is_taken;       /* whether the branch is taken */
    addr_t      target_addr;
} sbe_predict_t;

typedef struct packed {
    logic       valid;
    addr_t      addr;
    instr_t     instr;
    exception_t ex;
    sbe_predict_t   predict;
} fetch_entry_t;

parameter   IFQ_DEPTH   = `CONFIG_IFQ_DEPTH;

/* scoreboard */
parameter   SB_ENTRIES  = `CONFIG_SB_ENTRIES;

typedef logic [$clog2(SB_ENTRIES)-1:0] sb_idx_t;

/* the functional unit to be used */
typedef enum logic[3:0] {
    FU_NONE,      // 0
    FU_LOAD,      // 1
    FU_STORE,     // 2
    FU_ALU,       // 3
    FU_BRANCH,     // 4
    FU_MULT,      // 5
    FU_CSR,       // 6
    FU_FPU,       // 7
    FU_FPU_VEC    // 8
} fu_t;

/* the operation to perform */
typedef enum logic [6:0] {
    // basic ALU op
    ADD, SUB, ADDW, SUBW,
    // logic operations
    XORL, ORL, ANDL,
    // shifts
    SRA, SRL, SLL, SRLW, SLLW, SRAW,
    // comparisons
    BLTS, BLTU, BGES, BGEU, BEQ, BNE,
    // jumps
    JAL_R, BRANCH_R,
    // set lower than operations
    SLTS, SLTU,
    // CSR functions
    MRET, SRET, DRET, ECALL, WFI, FENCE, FENCE_I, SFENCE_VMA, CSR_WRITE, CSR_READ, CSR_SET, CSR_CLEAR,
    // LSU functions
    LD, SD, LW, LWU, SW, LH, LHU, SH, LB, SB, LBU,
    // Atomic Memory Operations
    AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
    AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW, AMO_MAXWU, AMO_MINW, AMO_MINWU,
    AMO_SWAPD, AMO_ADDD, AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU,
    // Multiplications
    MUL, MULH, MULHU, MULHSU, MULW,
    // Divisions
    DIV, DIVU, DIVW, DIVUW, REM, REMU, REMW, REMUW,
    // Floating-Point Load and Store Instructions
    FLD, FLW, FLH, FLB, FSD, FSW, FSH, FSB,
    // Floating-Point Computational Instructions
    FADD, FSUB, FMUL, FDIV, FMIN_MAX, FSQRT, FMADD, FMSUB, FNMSUB, FNMADD,
    // Floating-Point Conversion and Move Instructions
    FCVT_F2I, FCVT_I2F, FCVT_F2F, FSGNJ, FMV_F2X, FMV_X2F,
    // Floating-Point Compare Instructions
    FCMP,
    // Floating-Point Classify Instruction
    FCLASS,
    // Vectorial Floating-Point Instructions that don't directly map onto the scalar ones
    VFMIN, VFMAX, VFSGNJ, VFSGNJN, VFSGNJX, VFEQ, VFNE, VFLT, VFGE, VFLE, VFGT, VFCPKAB_S, VFCPKCD_S, VFCPKAB_D, VFCPKCD_D
} fu_op;

/* to represent both GP and FP registers, other than just RISC-V general
 * registers. */
localparam int unsigned NR_SBREGS = 32; /* only GP register for now */
typedef logic [$clog2(NR_SBREGS)-1:0]   sbreg_t;

typedef struct packed {
    logic   valid;  /* whether the value is valid */
    sbreg_t regno;  /* the value is stored in the register */
    data_t  value;  /* the operand value */
} operand_t;

typedef struct packed {
    logic       valid;
    addr_t      pc;         /* PC of instruction */
    sb_idx_t    index;      /* the entry location in the ScoreBoard */
    fu_t        fu;         /* functional unit to use */
    fu_op       op;         /* operation to perform in each functional unit */
    operand_t   operand1;   /* operand 1: the source register or value */
    operand_t   operand2;   /* operand 2: the source register or value */
    operand_t   operand3;   /* operand 3: the source register or value */
    operand_t   result;     /* result: the target register and value */
    exception_t ex;         /* exception has occurred */
    sbe_predict_t   predict;    /* branch predict scoreboard data structure */
} scoreboard_entry_t;

/* extraced information from scoreboard to execution */
typedef struct packed {
    sb_idx_t    index;
    fu_t        fu;
    fu_op       op;
    data_t      operand_a;
    data_t      operand_b;
} fu_data_t;

typedef struct packed {
    sb_idx_t    index;
    sbreg_t     rd;     /* redundant, just convenient to compare */
    data_t      result;
    exception_t ex;
} fu_result_t;

/* All information needed to determine whether we need to associate an interrupt
 * with the corresponding instruction or not.
 */
typedef struct packed {
  logic [63:0] mie;
  logic [63:0] mip;
  logic [63:0] mideleg;
  logic        sie;
  logic        global_enable;
} irq_ctrl_t;

endpackage: tortoise_pkg
