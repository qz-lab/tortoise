/*
 * File: branch_target_buffer.sv
 * Desc: branch target buffer used by 'jalr'
 *
 * Auth: QuanZhao
 * Date: Aug-05-2019
 *
 * Like the branch history table, this is a direct-associative cache.
 */

module branch_target_buffer #(
    parameter   NR_ENTRIES  = tortoise_pkg::BTB_ENTRIES,
    parameter   NR_LOOKUP   = tortoise_pkg::INSTR_PER_FETCH
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* fallback signals */
    input   logic   fb_valid_i,
    /* verilator lint_off UNUSED */
    input   riscv_pkg::addr_t   fb_branch_pc_i, fb_target_addr_i,

    /* lookup signals */
    input   riscv_pkg::addr_t   [NR_LOOKUP-1:0] branch_pc_i,
    /* verilator lint_on UNUSED */
    output  logic               [NR_LOOKUP-1:0] predict_valid_o,
    output  riscv_pkg::addr_t   [NR_LOOKUP-1:0] predict_target_o
);
    struct packed {
        logic valid;
        riscv_pkg::addr_t target;
    } [NR_ENTRIES-1:0] buffer;

    localparam  OFFSET      = 2;    /* the last 2 bits of pc are always 0. */
    localparam  INDEX_BITS  = $clog2(NR_ENTRIES);

    /* look up the predict result */
    always_comb begin: lookup
        logic [INDEX_BITS-1:0] index;
        for (int i = 0; i < NR_LOOKUP; i++) begin
            index = branch_pc_i[i][OFFSET +: INDEX_BITS];
            predict_valid_o[i]  = buffer[index].valid;
            predict_target_o[i] = buffer[index].target;
        end
    end: lookup

    /* update the predict buffer with fallback */
    logic [INDEX_BITS-1:0] fb_index;
    assign fb_index = fb_branch_pc_i[OFFSET +: INDEX_BITS];

    always_ff @(posedge clk_i or negedge rst_ni) begin: update
        if ((rst_ni == 1'b0) || (flush_i == 1'b1)) begin
                buffer <= {NR_ENTRIES{1'b0, riscv_pkg::addr_t'(0)}};
        end else begin
            if (fb_valid_i && (debug_mode_i == 1'b0)) begin: handle_fallback
                buffer[fb_index].valid  <= 1'b1;
                buffer[fb_index].target <= fb_target_addr_i;
            end: handle_fallback
        end
    end: update

endmodule: branch_target_buffer
