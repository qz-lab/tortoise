/*
 * File: ripple_carry_adder.sv
 * Desc: ripple carry adder
 *
 * Auth: QuanZhao
 * Date: Aug-27-2019
 *
 * This is what I learned from ADDVH. Learn and practice ;-)
 */

module half_adder (
    input   logic   a, b,
    output  logic   s, c
);
    assign  s = a ^ b;  /* sum bit */
    assign  c = a & b;  /* carry bit */
endmodule: half_adder

module full_adder (
    input   logic   a, b, carry_in,
    output  logic   sum, carry_out
);
    logic   s, c1, c2;

    half_adder ha1(.a, .b, .s, .c(c1));
    half_adder ha2(.a(s), .b(carry_in), .s(sum), .c(c2));

    assign  carry_out = c1 | c2;
endmodule: full_adder

module ripple_carry_adder #(
    parameter WIDTH = $bits(riscv_pkg::data_t)
) (
    input   logic               inv_b_i, carry_in_i,
    input   logic [WIDTH-1:0]   data_a_i, data_b_i,
    output  logic               carry_out_o,
    output  logic [WIDTH-1:0]   result_o
);
    logic [WIDTH-1:0]   data_a, data_b;
    assign  data_a  = data_a_i;     /* not necessary, just for convenience */
    assign  data_b  = inv_b_i ? ~data_b_i : data_b_i;

    /* Feed each carry bit from the previous adder to the current one. The first
     * carry bit comes from the input, and the last one goes to the output. */
    logic c[WIDTH:0];
    assign  c[0]        = carry_in_i;
    assign  carry_out_o = c[WIDTH];

    generate
        for (genvar i = 0; i < WIDTH; i++)
            full_adder fa(.a(data_a[i]), .b(data_b[i]), .carry_in(c[i]),
                .sum(result_o[i]), .carry_out(c[i+1]));
    endgenerate
endmodule: ripple_carry_adder
