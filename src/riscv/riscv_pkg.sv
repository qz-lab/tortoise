/*
 * File: riscv_pkg.sv
 * Desc: common declarations of RISC-V, but no implementaion details
 *
 * Auth: QuanZhao
 * Date: Aug-04-2019
 *
 * All the declarations come from the RISC-V specifications, some of them are
 * defined according to the user configuration. Other informaitons like cache
 * sizes, the issue algorithm and so on, should NOT be included here.
 */

`include "sysconfig.svh"

package riscv_pkg;

/* common structure */
`ifdef  CONFIG_RV64I_SUPPORT
    parameter   RV_XLEN = 64;      /* the widest supported XLEN */
`else
    parameter   RV_XLEN = 32;
`endif

typedef logic [RV_XLEN-1:0] data_t;
typedef logic [RV_XLEN-1:0] addr_t;

/* instruction formats */
typedef enum logic [6:0] {
    LOAD    = 7'B00_000_11,
    LOADFP  = 7'b00_001_11,
    CUSTOM0 = 7'b00_010_11,
    MISCMEM = 7'b00_011_11,
    OPIMM   = 7'b00_100_11,
    AUIPC   = 7'b00_101_11,
    OPIMM32 = 7'b00_110_11,

    STORE   = 7'b01_000_11,
    STOREFP = 7'b01_001_11,
    CUSTOM1 = 7'b01_010_11,
    AMO     = 7'b01_011_11,
    OP      = 7'b01_100_11,
    LUI     = 7'b01_101_11,
    OP32    = 7'b01_110_11,

    MADD    = 7'b10_000_11,
    MSUB    = 7'b10_001_11,
    NMSUB   = 7'b10_010_11,
    NMADD   = 7'b10_011_11,
    OPFP    = 7'b10_100_11,
    RSRVD1  = 7'b10_101_11,
    CUSTOM2 = 7'b10_110_11,

    BRANCH  = 7'b11_000_11,
    JALR    = 7'b11_001_11,
    RSRVD2  = 7'b11_010_11,
    JAL     = 7'b11_011_11,
    SYSTEM  = 7'b11_100_11,
    RSRVD3  = 7'b11_101_11,
    CUSTOM3 = 7'b11_110_11
} opcode_t;

typedef struct packed {
    logic [31:7]    rem;
    opcode_t        opcode;
} instr_t;

typedef logic [4:0] reg_t;

/* functions to get the immediate */
/* verilator lint_off UNUSED */
function automatic data_t i_imm(logic [31:7] rem);  /* 12 bits */
    return {{(RV_XLEN-12){rem[31]}}, rem[31:20]};
endfunction

function automatic data_t s_imm(logic [31:7] rem);  /* 12 bits */
    return {{(RV_XLEN-12){rem[31]}}, rem[31:25], rem[11:7]};
endfunction

function automatic data_t b_imm(logic [31:7] rem);  /* 12 bits, [12:1] */
    return {{(RV_XLEN-13){rem[31]}}, rem[31], rem[7], rem[30:25], rem[11:8],
        1'b0};
endfunction

function automatic data_t u_imm(logic [31:7] rem);  /* 20 bits, [31:12] */
    return {{(RV_XLEN-32){rem[31]}}, rem[31:12], 12'b0};
endfunction

function automatic data_t j_imm(logic [31:7] rem);  /* 20 bits, [20:1] */
    return {{(RV_XLEN-21){rem[31]}}, rem[31], rem[19:12], rem[20], rem[30:21],
        1'b0};
endfunction /* verilator lint_on UNUSED */

/* exceptions and interrupts */
typedef enum logic [RV_XLEN-1:0] {
    /* synchronous exception */
    INSTR_ADDR_MISALIGNED   = RV_XLEN'(0),
    INSTR_ACCESS_FAULT      = RV_XLEN'(1),
    ILLEGAL_INSTR           = RV_XLEN'(2),
    BREAKPOINT              = RV_XLEN'(3),
    LD_ADDR_MISALIGNED      = RV_XLEN'(4),
    LD_ACCESS_FAULT         = RV_XLEN'(5),
    ST_ADDR_MISALIGNED      = RV_XLEN'(6),
    ST_ACCESS_FAULT         = RV_XLEN'(7),
    ENV_CALL_UMODE          = RV_XLEN'(8),    /* environment call from user mode */
    ENV_CALL_SMODE          = RV_XLEN'(9),    /* environment call from supervisor mode */
    ENV_CALL_MMODE          = RV_XLEN'(11),   /* environment call from machine mode */
    INSTR_PAGE_FAULT        = RV_XLEN'(12),   /* Instruction page fault */
    LOAD_PAGE_FAULT         = RV_XLEN'(13),   /* Load page fault */
    STORE_PAGE_FAULT        = RV_XLEN'(15),   /* Store page fault */
    DEBUG_REQUEST           = RV_XLEN'(24),   /* Custom: Debug request */

    /* interrupt */
    U_SW_INTERRUPT          = {1'b1, (RV_XLEN-1)'(0)},
    S_SW_INTERRUPT          = {1'b1, (RV_XLEN-1)'(1)},
    M_SW_INTERRUPT          = {1'b1, (RV_XLEN-1)'(3)},
    U_TIMER_INTERRUPT       = {1'b1, (RV_XLEN-1)'(4)},
    S_TIMER_INTERRUPT       = {1'b1, (RV_XLEN-1)'(5)},
    M_TIMER_INTERRUPT       = {1'b1, (RV_XLEN-1)'(7)},
    U_EXT_INTERRUPT         = {1'b1, (RV_XLEN-1)'(8)},
    S_EXT_INTERRUPT         = {1'b1, (RV_XLEN-1)'(9)},
    M_EXT_INTERRUPT         = {1'b1, (RV_XLEN-1)'(11)}
} ex_cause_t;

localparam  logic [RV_XLEN-1:0] U_SW_INTR_MASK      = RV_XLEN'(1<<0);
localparam  logic [RV_XLEN-1:0] S_SW_INTR_MASK      = RV_XLEN'(1<<1);
localparam  logic [RV_XLEN-1:0] M_SW_INTR_MASK      = RV_XLEN'(1<<3);
localparam  logic [RV_XLEN-1:0] U_TIMER_INTR_MASK   = RV_XLEN'(1<<4);
localparam  logic [RV_XLEN-1:0] S_TIMER_INTR_MASK   = RV_XLEN'(1<<5);
localparam  logic [RV_XLEN-1:0] M_TIMER_INTR_MASK   = RV_XLEN'(1<<7);
localparam  logic [RV_XLEN-1:0] U_EXT_INTR_MASK     = RV_XLEN'(1<<8);
localparam  logic [RV_XLEN-1:0] S_EXT_INTR_MASK     = RV_XLEN'(1<<9);
localparam  logic [RV_XLEN-1:0] M_EXT_INTR_MASK     = RV_XLEN'(1<<11);

typedef logic [RV_XLEN-1:0] ex_tval_t;

/* interrupt */

/* Privilege */
// --------------------
// Privilege Spec
// --------------------
typedef enum logic[1:0] {
  PRIV_LVL_M = 2'b11,
  PRIV_LVL_S = 2'b01,
  PRIV_LVL_U = 2'b00
} priv_lvl_t;

// type which holds xlen
typedef enum logic [1:0] {
    XLEN_32  = 2'b01,
    XLEN_64  = 2'b10,
    XLEN_128 = 2'b11
} xlen_t;

typedef enum logic [1:0] {
    OFF     = 2'b00,
    INITIAL = 2'b01,
    CLEAN   = 2'b10,
    DIRTY   = 2'b11
} xs_t;

typedef struct packed {
    logic         sd;     // signal dirty state - read-only
    logic [62:36] wpri4;  // writes preserved reads ignored
    xlen_t        sxl;    // variable supervisor mode xlen - hardwired to zero
    xlen_t        uxl;    // variable user mode xlen - hardwired to zero
    logic [8:0]   wpri3;  // writes preserved reads ignored
    logic         tsr;    // trap sret
    logic         tw;     // time wait
    logic         tvm;    // trap virtual memory
    logic         mxr;    // make executable readable
    logic         sum;    // permit supervisor user memory access
    logic         mprv;   // modify privilege - privilege level for ld/st
    xs_t          xs;     // extension register - hardwired to zero
    xs_t          fs;     // floating point extension register
    priv_lvl_t    mpp;    // holds the previous privilege mode up to machine
    logic [1:0]   wpri2;  // writes preserved reads ignored
    logic         spp;    // holds the previous privilege mode up to supervisor
    logic         mpie;   // machine interrupts enable bit active prior to trap
    logic         wpri1;  // writes preserved reads ignored
    logic         spie;   // supervisor interrupts enable bit active prior to trap
    logic         upie;   // user interrupts enable bit active prior to trap - hardwired to zero
    logic         mie;    // machine interrupts enable
    logic         wpri0;  // writes preserved reads ignored
    logic         sie;    // supervisor interrupts enable
    logic         uie;    // user interrupts enable - hardwired to zero
} status_rv64_t;

typedef struct packed {
    logic         sd;     // signal dirty - read-only - hardwired zero
    logic [7:0]   wpri3;  // writes preserved reads ignored
    logic         tsr;    // trap sret
    logic         tw;     // time wait
    logic         tvm;    // trap virtual memory
    logic         mxr;    // make executable readable
    logic         sum;    // permit supervisor user memory access
    logic         mprv;   // modify privilege - privilege level for ld/st
    logic [1:0]   xs;     // extension register - hardwired to zero
    logic [1:0]   fs;     // extension register - hardwired to zero
    priv_lvl_t    mpp;    // holds the previous privilege mode up to machine
    logic [1:0]   wpri2;  // writes preserved reads ignored
    logic         spp;    // holds the previous privilege mode up to supervisor
    logic         mpie;   // machine interrupts enable bit active prior to trap
    logic         wpri1;  // writes preserved reads ignored
    logic         spie;   // supervisor interrupts enable bit active prior to trap
    logic         upie;   // user interrupts enable bit active prior to trap - hardwired to zero
    logic         mie;    // machine interrupts enable
    logic         wpri0;  // writes preserved reads ignored
    logic         sie;    // supervisor interrupts enable
    logic         uie;    // user interrupts enable - hardwired to zero
} status_rv32_t;

typedef struct packed {
    logic [3:0]  mode;
    logic [15:0] asid;
    logic [43:0] ppn;
} satp_t;
endpackage: riscv_pkg
