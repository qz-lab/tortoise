/*
 * File: store_unit.sv
 * Desc: buffer the explicit store requests until they are to be committed
 *
 * Auth: QuanZhao
 * Date: sep-05-2019
 *
 * The issued stores are bufferred in a speculative queue, where they stay until
 * a commit signal is received. At that time, a request is pop out and pushed
 * into the commit queue, where they execute in order.
 * What's more, if there is a load request issued which might overlap with one
 * store request in either queue, the load request must wait until the possible
 * overlapping is not valid.
 */

module store_unit #(
    parameter DEPTH_SPEC    = tortoise_pkg::WB_SPEC_ENTRIES,
    parameter DEPTH_COMMIT  = tortoise_pkg::WB_COMMIT_ENTRIES
) (
    input   logic  clk_i, rst_ni, flush_i, /* testmode_i, */

    input   logic   commit_store_i,     /* allow to commit the store */
    /* synchronize to avoid the overlap hazards */
    input   riscv_pkg::addr_t   load_addr_i,
    output  logic               load_wait_o,    /* load should wait */

    /* store request */
    input   logic   store_valid_i,
    output  logic   store_ready_o,
    input   tortoise_pkg::lsu_entry_t   store_i,

    /* store result */
    input   logic   store_result_ready_i,
    output  logic   store_result_valid_o,
    output  tortoise_pkg::fu_result_t   store_result_o,

    /* communication signals with the cache or system bus */
    output  logic   d_store_req_o,
    output  tortoise_pkg::phy_store_t   d_store_o,

    input   logic   d_store_ack_i, d_store_err_i,
    input   riscv_pkg::data_t   d_store_data_i  /* used for AMO */
);

    import  tortoise_pkg::*;

    lsu_entry_t spec_to_commit;     /* the signal path */
    /* the signals of the speculative queue */
    logic spec_full, spec_empty, spec_push, spec_pop;
    lsu_entry_t [WB_SPEC_ENTRIES-1:0]   spec_data;

    fifo #(
        .DTYPE (lsu_entry_t),
        .DEPTH (WB_SPEC_ENTRIES)
    ) spec_queue (
        .clk_i, .rst_ni, .flush_i,
        .expose_o(spec_data),
        .full_o(spec_full), .empty_o(spec_empty),
        .push_i(spec_push), .pop_i(spec_pop),
        .data_i(store_i), .data_o(spec_to_commit)
    );

    /* the signals of the speculative queue */
    logic commit_full, commit_empty, commit_push, commit_pop;
    lsu_entry_t committed_store;
    lsu_entry_t [WB_COMMIT_ENTRIES-1:0] commit_data;

    fifo #(
        .DTYPE (lsu_entry_t),
        .DEPTH (WB_COMMIT_ENTRIES)
    ) commit_queue (
        .clk_i, .rst_ni, .flush_i,
        .expose_o(commit_data),
        .full_o(commit_full), .empty_o(commit_empty),
        .push_i(commit_push), .pop_i(commit_pop),
        .data_i(spec_to_commit), .data_o(committed_store)
    );

    assign  store_ready_o   = ~spec_full;
    assign  spec_push       = store_valid_i & store_ready_o;
    /* we only transfer a store request from the speculative queue to the commit
     * one when we receive the signal from the commit stage. */
    assign  spec_pop        = ~spec_empty & ~commit_full & commit_store_i;
    assign  commit_push     = spec_pop;

    /* Now we care about the signals to the cache or system bus. */
    assign  d_store_req_o   = ~commit_empty & ~committed_store.ex.valid;
    assign  d_store_o       = '{
        addr: committed_store.paddr,
        size: committed_store.size,
        data: committed_store.data
    };

    /* the response of store */
    assign  store_result_valid_o = d_store_ack_i |
        (~commit_empty & committed_store.ex.valid);
    assign  commit_pop      = store_result_ready_i & store_result_valid_o;

    /* The load result comes from the previous exception or the real load data.
     * Note that the result is not bufferred. */
    exception_t store_ex;
    always_comb begin
        /* exception */
        if (~commit_empty & committed_store.ex.valid)
            store_ex    = committed_store.ex;
        else if (d_store_ack_i & d_store_err_i)
            store_ex    = '{
                valid:  1'b1,
                cause:  riscv_pkg::ST_ACCESS_FAULT,
                tval:   committed_store.vaddr
            };
        else store_ex = '0;
    end

    /* the store result back to the scoreboard */
    assign  store_result_o  = '{
        index:  committed_store.index,
        rd:     committed_store.rd,
        result: d_store_data_i,     /* should return 0 for normal stores */
        ex:     store_ex
    };

    /* At last, don't forget to wait for the previous overlapping stores to
     * complete. */
    always_comb begin
        /* We only need to compare with the valid one. */
        load_wait_o = 1'b0;
        for (int i = 0; i < WB_SPEC_ENTRIES; i++)
            load_wait_o |= spec_data[i].valid &
                (spec_data[i].paddr[63:3] == load_addr_i[63:3]);
        for (int i = 0; i < WB_COMMIT_ENTRIES; i++)
            load_wait_o |= commit_data[i].valid &
                (commit_data[i].paddr[63:3] == load_addr_i[63:3]);
    end

endmodule: store_unit
