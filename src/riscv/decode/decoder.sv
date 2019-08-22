/*
 * File: decoder.sv
 * Desc: decode the fetched instruction into ScoreBoard format
 *
 * Auth: QuanZhao
 * Date: Aug-14-2019
 */

module decoder (
`ifdef HANDLE_INTERRUPT_IN_DECODE
    /* interrupts */
    input  logic [1:0]         irq_i,
    input  irq_ctrl_t          irq_ctrl_i,

    input  riscv_pkg::xs_t     fs_i,        /* FP point extension status */
    input  logic [2:0]         frm_i,       /* FP dynamic rounding mode */
`endif
    /* from CSRs */
    input  riscv_pkg::priv_lvl_t    priv_lvl_i,  /* current privilege level */
    input  logic               debug_mode_i,/* we are in debug mode */
    input  logic               tvm_i,       /* trap virtual memory */
    input  logic               tw_i,        /* timeout wait */
    input  logic               tsr_i,       /* trap sret */
    /* input and output of decoding */
    input   tortoise_pkg::fetch_entry_t         fetch_i,
    output  tortoise_pkg::scoreboard_entry_t    sbe_o
);

    import riscv_pkg::*;
    import tortoise_pkg::*;
    import decode_pkg::*;

    logic   is_illegal;
    instr_t instr   = fetch_i.instr;

    /* Only 'fetch_i.instr' and 'fetch_i.ex' might be modified. */
    assign sbe_o.valid      = fetch_i.valid;
    assign sbe_o.pc         = fetch_i.addr;
    assign sbe_o.predict    = fetch_i.predict;

    always_comb begin: decode_instruction
        /* set default values */
        is_illegal          = 1'b0;
        sbe_o.index         = sb_idx_t'(0);
        sbe_o.fu            = FU_NONE;
        sbe_o.op            = ADD;
        sbe_o.operand1      = '0;
        sbe_o.operand2      = '0;
        /* operand3 is usually not needed, make it valid */
        sbe_o.operand3      = '{1, reg_t'(0), data_t'(0)};
        sbe_o.result        = '0;

        sbe_o.ex            = fetch_i.ex;

        if (~fetch_i.ex.valid) begin: handle_each_opcode
            unique case (instr.opcode)
                LOAD:   decode_LOAD     (instr, sbe_o, is_illegal);
                LOADFP: is_illegal = 1'b1;
                MISCMEM:decode_MISCMEM  (instr, sbe_o, is_illegal);
                OPIMM:  decode_OPIMM    (instr, sbe_o, is_illegal);
                AUIPC:  decode_AUIPC    (instr, sbe_o, .pc(fetch_i.addr));
                OPIMM32:decode_OPIMM32  (instr, sbe_o, is_illegal);
                STORE:  decode_STORE    (instr, sbe_o, is_illegal);
                STOREFP:is_illegal = 1'b1;

                AMO:    is_illegal = 1'b1;
                OP:     decode_OP       (instr, sbe_o, is_illegal);
                LUI:    decode_LUI      (instr, sbe_o);
                OP32:   decode_OP32     (instr, sbe_o, is_illegal);

                MADD, MSUB, NMADD, NMSUB: begin
                    is_illegal = 1'b1;
                end

                OPFP:   is_illegal = 1'b1;
                BRANCH: decode_BRANCH   (instr, sbe_o, is_illegal);
                JALR:   decode_JALR     (instr, sbe_o, is_illegal);

                JAL:    decode_JAL      (instr, sbe_o, .pc(fetch_i.addr));

                SYSTEM: decode_SYSTEM   (instr, sbe_o, is_illegal,
                        .priv(priv_lvl_i),
                        .tsr(tsr_i), .tw(tw_i), .tvm(tvm_i),
                        .debug_mode(debug_mode_i));

                default: is_illegal = 1;
            endcase
        end: handle_each_opcode

        /* Don't forget to handle the Illegal Instruction exceptions. We also
         * take care of the external interrupts and debug requests, as long as
         * there are no previous exceptions on this instruction. */
        if (is_illegal == 1'b1) begin
            sbe_o.ex = '{1'b1, ILLEGAL_INSTR, ex_tval_t'(instr)};
        end

/* not defined, delete after CSR implemented */
`ifdef HANDLE_INTERRUPT_IN_DECODE
        /* Here let me reference the ariane comments:
        * we decode an interrupt the same as an exception, hence it will be taken
        * if the instruction did not throw any previous exception. (However,
        * claimed in the specification, synchronous exceptions are of lower
        * priority than all interrupts.)
        * We have three interrupt sources: external interrupts, software
        * interrupts, timer interrupts (order of precedence) for two privilege
        * levels: Supervisor and Machine Mode. (xEI > xSI > xTI > exceptions)
        */
        logic [63:0]    irq_state = irq_ctrl_i.mie & irq_ctrl_i.mip;
        ex_cause_t      irq_cause;
        logic           is_delegated;

        unique case (1'b1)
            irq_state & M_EXT_INTR_MASK: begin
                irq_cause       = M_EXT_INTERRUPT;
                is_delegated    = irq_ctrl_i.mideleg & M_EXT_INTR_MASK;
            end
            irq_state & M_TIMER_INTR_MASK: begin
                irq_cause       = M_TIMER_INTERRUPT;
                is_delegated    = irq_ctrl_i.mideleg & M_TIMER_INTR_MASK;
            end
            irq_state & M_SW_INTR_MASK: begin
                irq_cause       = M_SW_INTERRUPT;
                is_delegated    = irq_ctrl_i.mideleg & M_SW_INTR_MASK;
            end
            irq_state & S_EXT_INTR_MASK: begin
                irq_cause       = S_EXT_INTERRUPT;
                is_delegated    = irq_ctrl_i.mideleg & S_EXT_INTR_MASK;
            end
            irq_state & S_TIMER_INTR_MASK: begin
                irq_cause       = S_TIMER_INTERRUPT;
                is_delegated    = irq_ctrl_i.mideleg & S_TIMER_INTR_MASK;
            end
            irq_state & S_SW_INTR_MASK: begin
                irq_cause       = S_SW_INTERRUPT;
                is_delegated    = irq_ctrl_i.mideleg & S_SW_INTR_MASK;
            end
            default: irq_cause  = 64'0;
        endcase

        if (irq_cause && irq_ctrl_i.global_enable) begin
            // However, if bit i in mideleg is set, interrupts are considered to be globally enabled if the hart’s current privilege
            // mode equals the delegated privilege mode (S or U) and that mode’s interrupt enable bit
            // (SIE or UIE in mstatus) is set, or if the current privilege mode is less than the delegated privilege mode.
            if (is_delegated) begin
                if ((irq_ctrl_i.sie && priv_lvl_i == riscv::PRIV_LVL_S) || priv_lvl_i == riscv::PRIV_LVL_U) begin
                    sbe_o.ex.valid = 1'b1;
                    sbe_o.ex.cause = irq_cause;
                end
            end else begin
                sbe_o.ex.valid = 1'b1;
                sbe_o.ex.cause = irq_cause;
            end
        end
`endif  /* HANDLE_INTERRUPT_IN_DECODE */

    end: decode_instruction

endmodule: decoder
