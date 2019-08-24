/*
 * File: find_first_one.sv
 * Desc: find the location of the first 1'b1 in a bit array
 *
 * Auth: QuanZhao
 * Date: Aug-23-2019
 */

module find_first_one #(
    parameter WIDTH         = 2,
    parameter COUNT_BITS    = $clog2(WIDTH) /* $clog2(2) = 1 */
) (
    input   logic [WIDTH-1:0]       data_i,
    input   logic [COUNT_BITS-1:0]  start_i,
    output  logic [COUNT_BITS-1:0]  index_o,
    output  logic valid_one_o
);

    assign valid_one_o   = |data_i;

    always_comb begin: lookup
        index_o = start_i;
        if (valid_one_o)
            while (data_i[index_o] != 1'b1) begin
                index_o = index_o + COUNT_BITS'(1);
            end
    end: lookup

endmodule: find_first_one
