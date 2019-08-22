/*
 * File: decode_stage.sv
 * Desc: decode the fetched instructions and pop them to issue.
 *
 * Auth: QuanZhao
 * Date: Aug-21-2019
 */

module decode_stage #(
    parameter NR_INSTRS = tortoise_pkg::INSTR_PER_FETCH
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* from CSRs */
    input  riscv_pkg::priv_lvl_t    priv_lvl_i,  /* current privilege level */
    input  logic               tvm_i,       /* trap virtual memory */
    input  logic               tw_i,        /* timeout wait */
    input  logic               tsr_i,       /* trap sret */
    /* load a group of decoded instructions */
    input   logic   fetch_valid_i,
    output  logic   fetch_pop_o,
    input   tortoise_pkg::fetch_entry_t [NR_INSTRS-1:0]   fetch_i,

    /* pop only one each time */
    input   logic   issue_pop_i,
    output  logic   issue_valid_o,
    output  tortoise_pkg::scoreboard_entry_t    issue_instr_o
);

    tortoise_pkg::scoreboard_entry_t [NR_INSTRS-1:0]    decoded_instrs;

    generate
        for (genvar i = 0; i < NR_INSTRS; i++)
            decoder id(.fetch_i(fetch_i[i]), .sbe_o(decoded_instrs[i]),
                    .priv_lvl_i, .debug_mode_i, .tvm_i, .tw_i, .tsr_i);
    endgenerate

    issue_port  port (
        .clk_i, .rst_ni, .flush_i, .debug_mode_i,

        .instr_valid_i(fetch_valid_i), .instr_load_o(fetch_pop_o),
        .instr_i(decoded_instrs),

        .issue_pop_i, .issue_valid_o, .issue_instr_o);
endmodule: decode_stage
