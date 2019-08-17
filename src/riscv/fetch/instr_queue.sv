/*
 * File: instr_queue.sv
 * Desc: store the fetched instructions for the next stage (ID)
 *
 * Auth: QuanZhao
 * Date: Aug-13-2019
 */

module instr_queue #(
    parameter INSTR_PER_ROW = tortoise_pkg::INSTR_PER_FETCH,
    parameter DEPTH         = tortoise_pkg::IFQ_DEPTH
) (
    input   logic clk_i, rst_ni, flush_i,

    /* status flags */
    output  logic  full_o, empty_o,

    /* control and data signals */
    input   logic  push_i, pop_i,
    input   tortoise_pkg::fetch_entry_t [INSTR_PER_ROW-1:0] instr_i,
    output  tortoise_pkg::fetch_entry_t [INSTR_PER_ROW-1:0] instr_o
);
    /* Finally, it ends up with a big FIFO :-) */
    fifo #(
        .DEPTH (DEPTH),
        .DTYPE (tortoise_pkg::fetch_entry_t [INSTR_PER_ROW-1:0])
    ) i_fifo (
        .clk_i, .rst_ni, .flush_i,
        .full_o, .empty_o,
        /* verilator lint_off PINCONNECTEMPTY */
        .usage_o(),
        /* verilator lint_on PINCONNECTEMPTY */
        .push_i, .pop_i, .data_i(instr_i), .data_o(instr_o)
    );
endmodule: instr_queue
