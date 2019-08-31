/*
 * File: gpreg_file.sv
 * Desc: General Purpose Register File
 *
 * Auth: QuanZhao
 * Date: Aug-31-2019
 *
 * Only the commit stage writes the register file. Althought there are
 * 3 possible operands in a instruction, it doesn't need to read the same number
 * of registers for integer operations.
 *
 * However, more write and read ports are required for multiple-commit or
 * multiple-issue support. For now, they are set up as 1 and 3 respectively.
 */

module gpreg_file #(
    parameter NR_READ_PORTS     = tortoise_pkg::GPREG_READ_PORTS,
    parameter NR_WRITE_PORTS    = tortoise_pkg::GPREG_WRITE_PORTS
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* read ports */
    input   riscv_pkg::reg_t  [NR_READ_PORTS-1:0]   r_reg_i,
    output  riscv_pkg::data_t [NR_READ_PORTS-1:0]   r_data_o,

    /* write ports */
    input   logic             [NR_WRITE_PORTS-1:0]  w_en_i,
    input   riscv_pkg::reg_t  [NR_WRITE_PORTS-1:0]  w_reg_i,
    input   riscv_pkg::data_t [NR_WRITE_PORTS-1:0]  w_data_i
);

    import riscv_pkg::reg_t;
    import riscv_pkg::data_t;

    data_t [31:1]   regfile;    /* no x0 */

    always_comb begin: read
        for (int i = 0; i < NR_READ_PORTS; i++) begin
            automatic reg_t r_reg = r_reg_i[i];
            if (r_reg == '0)
                r_data_o[i] = '0;           /* x0 */
            else
                r_data_o[i] = regfile[r_reg];
        end
    end: read

    always_ff @(posedge clk_i or negedge rst_ni) begin: write
        if ((rst_ni == 1'b0) || (flush_i == 1'b1)) begin
            regfile <= '0;
        end else begin
            for (int i = 0; i < NR_WRITE_PORTS; i++) begin
                automatic reg_t w_reg = w_reg_i[i];
                if ((w_reg != '0) && (w_en_i[i] == 1'b1))
                    regfile[w_reg]      <= w_data_i[i];
            end
        end
    end: write
endmodule: gpreg_file
