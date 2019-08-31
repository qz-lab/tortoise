/*
 * File: alu.sv
 * Desc: the Arithmetic-Logic Unit
 *
 * Auth: QuanZhao
 * Date: Aug-27-2019
 */

module alu (
    input   logic   alu_valid_i,
    output  logic   alu_ready_o,
    input   tortoise_pkg::fu_data_t     alu_data_i,

    input   logic   alu_result_ready_i,
    output  logic   alu_result_valid_o,
    output  tortoise_pkg::fu_result_t   alu_result_o
);

    import  riscv_pkg::data_t;
    import  tortoise_pkg::*;

    /* All the ALU operations complete in one clock cycle. */
    assign  alu_result_valid_o  = alu_valid_i;
    assign  alu_ready_o         = alu_result_ready_i;

    /* We always calculate the sum. */
    logic   is_minus, overflow;
    data_t  a, b, c, alu_sum, alu_sum32;
    assign  a = alu_data_i.operand_a;
    assign  b = alu_data_i.operand_b;
    assign  c = alu_data_i.operand_c;

    ripple_carry_adder #(
        .WIDTH ($bits(data_t))
    ) rca (
        .inv_b_i(is_minus), .carry_in_i(is_minus),
        .data_a_i(a), .data_b_i(b),
        .carry_out_o(overflow), .result_o(alu_sum)
    );
    assign  alu_sum32   = {{32{alu_sum[31]}}, alu_sum[31:0]};

    data_t  result;
    assign  alu_result_o.result = result;   /* just make the name short */

    always_comb begin
        is_minus            = 1'b0;
        alu_result_o.index  = alu_data_i.index;
        alu_result_o.rd     = alu_data_i.rd;
        alu_result_o.ex     = '0;

        unique case (alu_data_i.op)
            /* 64-bit */
            ADD: begin
                is_minus    = 1'b0;
                result      = alu_sum;
            end
            SUB: begin
                is_minus    = 1'b1;
                result      = alu_sum;
            end
            SLL:    result  = a << b[5:0];
            CMP_LTS: begin
                /* Less-Than is true if:
                 * 1. a > 0, b > 0 and overflow == 1'b0;
                 * 2. a < 0, b < 0 and overflow == 1'b0;
                 * 3. a > 0, b < 0 (always Greater-Than and overflow == 1'b0);
                 * 4. a < 0, b < 0 (always Less-Than    and overflow == 1'b1).
                 */
                is_minus    = 1'b1;
                result      = data_t'(a[63] ^ b[63] ^ (~overflow));
            end
            CMP_LTU: begin
                is_minus    = 1'b1;
                result      = data_t'(~overflow);
            end
            CMP_GES: begin
                is_minus    = 1'b1;
                result      = data_t'(~(a[63] ^ b[63] ^ (~overflow)));
            end
            CMP_GEU: begin
                is_minus    = 1'b1;
                result      = data_t'(overflow);
            end
            CMP_NE: begin
                is_minus    = 1'b1;
                result      = data_t'(|alu_sum);
            end
            CMP_EQ: begin
                is_minus    = 1'b1;
                result      = data_t'(~(|alu_sum));
            end
            XORL:   result  = a ^ b;
            SRL:    result  = a >> b[5:0];
            SRA:    result  = a >>> b[5:0];
            ORL:    result  = a | b;
            ANDL:   result  = a & b;

            /* 32-bit */
            ADDW: begin
                is_minus    = 1'b0;
                result      = alu_sum32;
            end
            SUBW: begin
                is_minus    = 1'b1;
                result      = alu_sum32;
            end
            SLLW: begin
                automatic logic [31:0] shift32 = a[31:0] << b[4:0];
                result      = {{32{shift32[31]}}, shift32};
            end
            SRLW:   result  = {{32{1'b0}}, a[31:0] >> b[4:0]};
            SRAW:   result  = {{32{a[31]}}, a[31:0] >>> b[4:0]};

            /* JALR is special. We return the link address and put the target
             * addrss in the exception no matter whether there is one or not. */
            JAL_R: begin
                is_minus    = 1'b0;
                result      = c;    /* link address, calculated in ID */
                alu_result_o.ex = '{
                    valid:  alu_sum[1:0] != 2'b00,
                    cause:  riscv_pkg::INSTR_ADDR_MISALIGNED,
                    tval:   alu_sum
                };
            end
            default: /* should not happned */;
        endcase
    end

endmodule: alu
