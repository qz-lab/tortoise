/*
 * File: load_unit.sv
 * Desc: handle the explicit load instructions (not including IF and PTW)
 *
 * Auth: QuanZhao
 * Date: Sep-03-2019
 *
 * Explicit loads and stores are handled to maintain the memory model. In this
 * implementation, loads might execute ahead if there is no possibility to
 * overlap with previous stores; Otherwise, the program order is followed.
 */

module load_unit (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* load request */
    input   logic   load_valid_i,
    output  logic   load_ready_o,
    input   tortoise_pkg::lsu_entry_t   load_i,

    /* load result to the scoreboard */
    input   logic   load_result_ready_i,
    output  logic   load_result_valid_o,
    output  tortoise_pkg::fu_result_t   load_result_o,

    /* we need to wait the previous overlapping stores to complete. */
    output  riscv_pkg::addr_t   load_addr_o,
    input   logic               load_wait_i,    /* load should wait */

    /* load data from cache or system bus */
    output  logic   d_load_req_o,
    output  tortoise_pkg::phy_load_t    d_load_o,

    input   logic   d_load_ack_i, d_load_err_i,
    input   riscv_pkg::data_t   d_load_data_i
);

    import  riscv_pkg::*;
    import  tortoise_pkg::*;

    /* We only buffer one load request to commit and wait for the result. Note
     * if there is a previous exception, return immediately and no request is
     * buffered. */
    //struct packed { logic valid; lsu_entry_t entry; } load_buffer;
    lsu_entry_t load_buffer;
    assign  load_addr_o = load_buffer.paddr;

    /* load buffer handshake signals from the scoreboard */
    assign  load_ready_o  = ~load_buffer.valid |
            (load_result_valid_o & load_result_ready_i);

    /* load signals from the load buffer to the cache or the system bus */
    assign  d_load_req_o    = load_buffer.valid & ~load_buffer.ex.valid &
        ~load_wait_i;
    assign  d_load_o    =   '{
        addr: load_buffer.paddr,
        size: load_buffer.size
    };

    /* return the load result if there is an exception or we get the data */
    assign  load_result_valid_o = d_load_ack_i |
        (load_buffer.valid & load_buffer.ex.valid);

    /* The load result comes from the previous exception or the real load data.
     * Note that the result is not bufferred. */
    exception_t load_ex;
    data_t      load_data;
    always_comb begin
        /* exception */
        if (load_buffer.valid & load_buffer.ex.valid)
            load_ex = load_buffer.ex;
        else if (d_load_ack_i & d_load_err_i)
            load_ex = '{
                valid:  1'b1,
                cause:  riscv_pkg::LD_ACCESS_FAULT,
                tval:   load_buffer.vaddr
            };
        else load_ex = '0;

        /* load data, sign- or zeor-extension */
        unique case (d_load_o.size)
            SZ_1B:  load_data = load_buffer.is_s                ?
                {{56{d_load_data_i[7]}}, d_load_data_i[7:0]}    :
                {{56{1'b0}}, d_load_data_i[7:0]};
            SZ_2B:  load_data = load_buffer.is_s                ?
                {{48{d_load_data_i[15]}}, d_load_data_i[15:0]}  :
                {{48{1'b0}}, d_load_data_i[15:0]};
            SZ_4B:  load_data = load_buffer.is_s                ?
                {{32{d_load_data_i[31]}}, d_load_data_i[31:0]}  :
                {{32{1'b0}}, d_load_data_i[31:0]};
            default:    load_data   = d_load_data_i;
        endcase
    end

    /* the load result back to the scoreboard */
    assign  load_result_o   = '{
        index:  load_buffer.index,
        rd:     load_buffer.rd,
        result: load_data,
        ex:     load_ex
    };

    always_ff @(posedge clk_i or negedge rst_ni) begin: commit_load
        if ((rst_ni == 1'b0) || (flush_i == 1'b1)) begin
            load_buffer.valid   <= 1'b0;
        end else begin
            if (load_valid_i & load_ready_o)
                load_buffer     <= load_i;
            else if (load_result_valid_o & load_result_ready_i)
                load_buffer.valid   <= 1'b0;
        end
    end: commit_load

endmodule: load_unit
