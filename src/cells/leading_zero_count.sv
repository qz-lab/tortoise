/*
 * File: leading_zero_count.sv
 * Desc: count the number of the leading zeros
 *
 * Auth: QuanZhao
 * Date: Aug-06-2019
 */

module leading_zero_count #(
    parameter WIDTH         = 2,
    parameter COUNT_BITS    = $clog2(WIDTH)
) (
    input   logic [WIDTH-1:0]       data_i,
    output  logic [COUNT_BITS-1:0]  count_o,
    output  logic allzero_o
);

    assign allzero_o = (|data_i) == 1'b0;

    always_comb begin
        count_o = COUNT_BITS'(0);
        for (int i = 0; i < WIDTH; i++) begin
            if (data_i[i] == 1'b0)
                count_o += COUNT_BITS'(1);
            else
                break;
        end
    end

endmodule: leading_zero_count
