/*
 * File: leading_zero_count.sv
 * Desc: count the number of the leading zeros
 *
 * Auth: QuanZhao
 * Date: Aug-06-2019
 */

module leading_zero_count #(
    parameter WIDTH         = 2,
    parameter COUNT_BITS    = $clog2(WIDTH) /* $clog2(2) = 1 */
) (
    input   logic [WIDTH-1:0]       data_i,
    output  logic [COUNT_BITS-1:0]  count_o,
    output  logic not_all_zero_o
);

    assign not_all_zero_o   = |data_i;

    always_comb begin: counting
        count_o = COUNT_BITS'(0);
        if (not_all_zero_o)
            for (int i = 0; i < WIDTH; i++) begin
                if (data_i[i] == 1'b0)
                    count_o += COUNT_BITS'(1);
                else
                    break;
            end
    end: counting

endmodule: leading_zero_count
