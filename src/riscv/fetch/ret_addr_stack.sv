/*
 * File: ret_addr_stack.sv
 * Desc: return address stack
 *
 * Auth: QuanZhao
 * Date: Aug-04-2019
 *
 * There are 2 things to note:
 * 1. The return address is pushed into the stack on every call even when the
 * stack is full, in this case, the oldest return address is lost.
 * 2. The stack is cleared on task switches, OS might save and restore the
 * content to improve the accuracy. However, it is not supported for now.
 */

module ret_addr_stack #(
    parameter DEPTH = tortoise_pkg::RAS_DEPTH
) (
    input   logic   clk_i, rst_ni, flush_i,

    /* control signals */
    input   logic   push_i, pop_i,

    /* input and output data */
    input   riscv_pkg::addr_t   ret_addr_i,
    output  riscv_pkg::addr_t   ret_addr_o,
    output  logic   valid_o
);
    struct packed {
        logic               valid;
        riscv_pkg::addr_t   ret_addr;
    } [DEPTH-1:0] stack;

    /* always output the stack top */
    assign valid_o      = stack[0].valid;
    assign ret_addr_o   = stack[0].ret_addr;

    always_ff @(posedge clk_i or negedge rst_ni) begin: push_pop_block
        if ((rst_ni == 1'b0) || (flush_i == 1'b1)) begin
                stack <= '0;
        end else begin: push_or_pop
            /* verilator lint_off CASEINCOMPLETE */
            case ({push_i, pop_i})
                2'b10: begin
                    stack[DEPTH-1:1] <= stack[DEPTH-2:0];   /* move deeper */
                    stack[0] <= '{1'b1, ret_addr_i};
                end
                2'b01: begin
                    stack[DEPTH-2:0] <= stack[DEPTH-1:1];   /* move shallower */
                    stack[DEPTH-1] <= '0;
                end
                2'b11: begin
                    stack[0] <= '{1'b1, ret_addr_i};
                end
            endcase
            /* verilator lint_on CASEINCOMPLETE */
        end: push_or_pop
    end: push_pop_block

endmodule: ret_addr_stack
