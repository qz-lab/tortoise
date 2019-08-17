/*
 * File: branch_history_table.sv
 * Desc: branch history table - 2-bit saturation counter
 *
 * Auth: QuanZhao
 * Date: Aug-04-2019
 *
 * Basically, this is a direct-associative cache.
 */

module branch_history_table #(
    parameter   NR_ENTRIES  = tortoise_pkg::BHT_ENTRIES,
    parameter   NR_LOOKUP   = tortoise_pkg::INSTR_PER_FETCH
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* fallback signals */
    input   logic   fb_valid_i, fb_branch_taken_i,  /* update the history */
    /* verilator lint_off UNUSED */
    input   riscv_pkg::addr_t   fb_branch_pc_i,

    /* lookup signals */
    input   riscv_pkg::addr_t   [NR_LOOKUP-1:0] branch_pc_i,
    /* verilator lint_on UNUSED */
    output  logic               [NR_LOOKUP-1:0] predict_valid_o,
    output  logic               [NR_LOOKUP-1:0] predict_taken_o
);

    struct packed {
        logic valid;
        logic [1:0] counter;
    } [NR_ENTRIES-1:0] history;

    localparam  OFFSET      = 2;    /* the last 2 bits of pc are always 0. */
    localparam  INDEX_BITS  = $clog2(NR_ENTRIES);

    /* look up the predict result */
    always_comb begin: lookup
        logic [INDEX_BITS-1:0] index;
        for (int i = 0; i < NR_LOOKUP; i++) begin
            index = branch_pc_i[i][OFFSET +: INDEX_BITS];
            predict_valid_o[i]  = history[index].valid;
            predict_taken_o[i]  = history[index].counter[1];
        end
    end: lookup

    /* update the predict history with fallback */
    logic [INDEX_BITS-1:0] fb_index;
    assign fb_index = fb_branch_pc_i[OFFSET +: INDEX_BITS];

    always_ff @(posedge clk_i or negedge rst_ni) begin: update
        if ((rst_ni == 1'b0) || (flush_i == 1'b1)) begin
                history <= {NR_ENTRIES{1'b0, 2'b10}};
        end else begin
            if (fb_valid_i && (debug_mode_i == 1'b0)) begin: handle_fallback
                history[fb_index].valid <= 1'b1;

                if (fb_branch_taken_i == 1'b1)
                    history[fb_index].counter <=
                        (history[fb_index].counter == 2'b11) ?
                        2'b11 : 2'(history[fb_index] + 2'b01);
                else
                    history[fb_index].counter <=
                        (history[fb_index].counter == 2'b00) ?
                        2'b00 : 2'(history[fb_index] - 2'b01);
            end: handle_fallback
        end
    end: update

endmodule: branch_history_table
