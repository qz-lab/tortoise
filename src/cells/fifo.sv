/*
 * File: fifo.sv
 * Desc: First In First Out - inspired by 'ariane' fifo_v3
 *
 * Auth: QuanZhao
 * Date: Aug-13-2019
 */
module fifo #(
    parameter DATA_WIDTH    = 32,   /* the width of each entry */
    parameter DEPTH         = 8,    /* the number of entries */
    parameter type DTYPE    = logic [DATA_WIDTH-1:0],
    parameter INDEX_BITS    = $clog2(DEPTH+1)
)(
    /* test_mode to bypass clock gating ? */
    input  logic  clk_i, rst_ni, flush_i, /* testmode_i, */

    /* status flags */
    output logic  full_o, empty_o,
    output logic  [INDEX_BITS-1:0] usage_o,

    /* control and data signals */
    input  logic  push_i, pop_i,
    input  DTYPE  data_i,
    output DTYPE  data_o
);
    logic [INDEX_BITS-1:0]  read_index, write_index;
    DTYPE [DEPTH-1:0]       mem;

    assign full_o   = (usage_o == DEPTH);
    assign empty_o  = (usage_o == '0);
    assign data_o   = mem[read_index];

    logic push, pop;
    assign push = push_i & (~full_o);
    assign pop  = pop_i & (~empty_o);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if ((rst_ni == 1'b0) || (flush_i == 1'b1)) begin: reset_or_flush
            mem     <= {DEPTH{DTYPE'(0)}};

            usage_o <= INDEX_BITS'(0);
            read_index  <= INDEX_BITS'(0);
            write_index <= INDEX_BITS'(0);
        end: reset_or_flush
        else begin: push_pop
            if (push) begin
                mem[write_index]    <= data_i;
                write_index <= (write_index == DEPTH-1) ? '0 : write_index + 1;
            end

            if (pop) begin
                read_index <= (read_index == DEPTH-1) ? '0 : read_index + 1;
            end

            /* 'usage_o' needs to be handled carefully when both 'push_i' and
             * 'pop_i' are set. */
           unique case ({push, pop})
                2'b10: usage_o  <= usage_o + 1;
                2'b01: usage_o  <= usage_o - 1;
                default: usage_o    <= usage_o;
           endcase
        end: push_pop
    end
endmodule: fifo
