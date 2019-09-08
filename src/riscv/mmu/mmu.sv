/*
 * File: mmu.sv
 * Desc: Memory Management Unit - address translation, access rights, flags
 *
 * Auth: QuanZhao
 * Date: Sep-01-2019
 *
 * All external accesses must pass MMU to verify the access rights and translate
 * the virtual addresses to the physical ones, which includes instruction
 * fetches, TLB walks and Load/Store operations.
 *
 * Note that, fetches and TLB walks are both load operations and have only the
 * 'req' signal. Their 'ack' signals are connected to the target components.
 * For now, let's ignore the translations and access rights.
 */

module mmu #(
    parameter INSTR_PER_FETCH = tortoise_pkg::INSTR_PER_FETCH
) (
    /* only used by the Page Table Walker */
    //input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* access requests from the Scoreboard */
    input   logic   lsu_valid_i,
    output  logic   lsu_ready_o,
    input   tortoise_pkg::fu_data_t     lsu_data_i,

    /* fetch requests from the fetch stage, which is pretty straight */
    input   logic                       fetch_req_i,
    input   riscv_pkg::addr_t           fetch_addr_i,

    /* the signals of translated load/store requests, the results are
     * transferred back to the scoreboard. */
    output  logic   daccess_valid_o,
    input   logic   daccess_ready_i,
    output  tortoise_pkg::lsu_entry_t  daccess_o,

    /* the signals of translated fetch requests, the results are transferred
     * back to the fetch stage. */
    output  logic   iaccess_req_o,
    output  tortoise_pkg::phy_load_t    iaccess_o,
    output  tortoise_pkg::exception_t   iaccess_ex_o

    /* TODO: the Page Table Walk port, similar to iaccess */
);

    import tortoise_pkg::*;
    import riscv_pkg::*;

    /*
     * Either the fetch or the load/store request must be translated first, and
     * then proceed for the real operations. Their results are not bufferred
     * here.  The clock signal is only used by the PTW.
     */
    /* calculate the address and the bytes to read or write */
    addr_t  d_addr  = lsu_data_i.operand_a + lsu_data_i.operand_b;
    size_t  d_size;
    logic   is_signed, is_store;
    always_comb begin
        is_signed   = 1'b1;
        is_store    = 1'b0;
        unique case (lsu_data_i.op)
            LB:     begin d_size = SZ_1B; end
            LH:     begin d_size = SZ_2B; end
            LW:     begin d_size = SZ_4B; end
            LD:     begin d_size = SZ_8B; end
            SB:     begin d_size = SZ_1B; is_store = 1'b1; end
            SH:     begin d_size = SZ_2B; is_store = 1'b1; end
            SW:     begin d_size = SZ_4B; is_store = 1'b1; end
            SD:     begin d_size = SZ_8B; is_store = 1'b1; end
            LBU:    begin d_size = SZ_1B; is_signed = 1'b0; end
            LHU:    begin d_size = SZ_2B; is_signed = 1'b0; end
            LWU:    begin d_size = SZ_4B; is_signed = 1'b0; end
            default:;
        endcase
    end

    /* TLB is not valid now, just put fake signals here. */
    logic       d_tlb_hit   = lsu_valid_i;  /* depends on 'lsu_valid_i' */
    addr_t      d_tlb_addr  = d_addr;       /* direct map */
    exception_t d_tlb_ex    = '0;           /* no exception */

    /* are we ready to update the translation result */
    assign      lsu_ready_o     = daccess_ready_i;
    assign      daccess_valid_o = d_tlb_hit;

    assign      daccess_o   = '{
        index:  lsu_data_i.index,
        rd:     lsu_data_i.rd,

        valid:  1'b1,
        is_w:   is_store,
        is_s:   is_signed,
        vaddr:  d_addr,
        paddr:  d_tlb_addr,
        size:   d_size,
        data:   lsu_data_i.operand_c,
        ex:     d_tlb_ex
    };

    /*
     * The instruction fetch process is pretty straight, since we have to wait
     * for the fetched instructions, we don't need to buffer the operations. We
     * either fetch 1 instruction (4-byte aligned) or 2 instructions (8-byte
     * aligned) at a time.
     */
    /* TLB is not valid now, just put fake signals here. */
    logic       i_tlb_hit   = fetch_req_i;  /* depends on 'fetch_req_i' */
    addr_t      i_tlb_addr  = fetch_addr_i; /* direct map */
    exception_t i_tlb_ex    = '0;           /* no exception */

    /* As I said, the fetch signals are held until the result is confirmed. */
    assign  iaccess_o.size  = fetch_addr_i[2] ? SZ_4B : SZ_8B;
    assign  iaccess_o.addr  = i_tlb_addr;
    assign  iaccess_req_o   = i_tlb_hit;
    assign  iaccess_ex_o    = i_tlb_ex;

endmodule: mmu
