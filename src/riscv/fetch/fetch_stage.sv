/*
 * File: fetch_stage.sv
 * Desc: Fetch Stage
 *
 * Auth: QuanZhao
 * Date: Aug-05-2019
 *
 * The stage waits or fetches several instructions on every clock edge, scans
 * the branches and jumps, predics whether the branch is taken or the target
 * address, then push the results and the instructions into a queue, so they
 * could be handled in the next stage.
 * At the same time, we need to change PC according to the target address.
 */

module fetch_stage #(
    parameter INSTR_PER_FETCH = tortoise_pkg::INSTR_PER_FETCH
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* fallback signals to update the prediction history */
    input   logic                   fb_valid_i, fb_branch_taken_i,
    input   riscv_pkg::addr_t       fb_branch_pc_i, fb_target_addr_i,
    input   tortoise_pkg::predict_t fb_type_i,

    /* fetch instructions from the lower level */
    output  logic                       fetch_req_o,
    output  riscv_pkg::addr_t           fetch_addr_o,

    input   logic   fetch_ack_i,
    input   tortoise_pkg::exception_t   fetch_ex_i,
    input   riscv_pkg::instr_t [INSTR_PER_FETCH-1:0]    instrs_i,

    /* output the scaned instructions to the next stage */
    input   logic   ready_i,
    output  logic   valid_o,
    output  tortoise_pkg::fetch_entry_t [INSTR_PER_FETCH-1:0]   fetch_o
);

    import riscv_pkg::addr_t;
    import riscv_pkg::instr_t;

    /* first, fetch instructions */
    addr_t  fetch_addr, PC;   /* PC: program counter */
    instr_t [INSTR_PER_FETCH-1:0]   fetched_instrs;

    assign fetch_addr_o = PC;
    always_ff @(posedge clk_i or negedge rst_ni) begin: fetch_instr
        if (rst_ni == 1'b0) begin
            fetched_instrs <= {INSTR_PER_FETCH{instr_t'(0)}};
        end else begin
            if (fetch_req_o & fetch_ack_i) begin    /* handshake */
                fetch_addr      <= PC;          /* the pc */
                fetched_instrs  <= instrs_i;    /* the fetched instruction */
            end
        end
    end: fetch_instr

    /* then scan the branches included */
    addr_t  [INSTR_PER_FETCH-1:0]   fetched_addrs;
    for (genvar i = 0; i < INSTR_PER_FETCH; i++) begin
        fetched_addrs[i] = fetch_addr + (4*i);    /* 4 bytes each instruction */
    end

    sbe_predict_t [INSTR_PER_FETCH-1:0] sbe_predict;
    branch_scan #(
        .NR_INSTR (INSTR_PER_FETCH)
    ) if_scan (
        /* update */
        .clk_i, .rst_ni, .flush_i, .debug_mode_i,
        .fb_valid_i, .fb_branch_pc_i, .fb_branch_taken_i,
        .fb_target_addr_i, .fb_type_i,
        /* lookup */
        .branch_pc_i(fetched_addrs), .instr_i(fetched_instrs),
        .sbe_predict_o(sbe_predict)
    );

    /* filter out the instructions behind the taken branch */
    fetch_entry_t [INSTR_PER_FETCH-1:0] scaned_fetch, valid_fetch
    logic   set_pc_branch;
    riscv_pkg::addr_t   pc_branch;

    for (genvar i = 0; i < INSTR_PER_FETCH; i++) begin
        scaned_fetch[i].addr    = fetched_addrs[i];
        scaned_fetch[i].instr   = fetched_instrs[i];
        scaned_fetch[i].predict = sbe_predict[i];
        scaned_fetch[i].ex      = fetch_ex_i;           /* fix it */
    end

    first_taken_branch #(
        .NR_INSTR (INSTR_PER_FETCH)
    ) if_valid (
        .instrs_i(scaned_fetch),
        .instrs_o(valid_fetch),
        .has_taken_branch(set_pc_branch),
        .target_addr(pc_branch)
    );

    /* at last, push the scaned instructions into the queue */
    logic is_queue_full, is_queue_empty;
    assign fetch_req_o  = ~is_queue_full;
    assign valid_o      = ~is_queue_empty;

    instr_queue #(
        .INSTR_PER_ROW (INSTR_PER_FETCH)
        .DPETH (tortoise_pkg::IFQ_DEPTH)
    ) if_queue (
        .clk_i, .rst_ni, .flush_i,
        .full_o(is_queue_full), .empty_o(is_queue_empty),
        .push_i(fetch_ack_i), .pop_i(ready_i),
        .instr_i(valid_fetch), .instr_o(fetch_o)
    );

    /* Don't forget to update PC. Incomplete for now. */
    always_ff @(posedge clk_i or negedge rst_i) begin: update_pc
        if (rst_i == 1'b0)
            PC <= boot_addr_i;
        else begin
            priority case (1'b1)
                set_pc_branch:  PC <= pc_branch;
            endcase
        end
    end: update_pc
endmodule: fetch_stage
