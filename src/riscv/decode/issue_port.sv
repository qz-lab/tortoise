/*
 * File: issue_port.sv
 * Desc: buffer the decoded instructions to issue
 *
 * Auth: QuanZhao
 * Date: Aug-21-2019
 *
 * For now, we only issue one instruction to the ScoreBoard at a time. When
 * there is not valid instructions in the buffer, load the new group. Basically,
 * this is kind of a serializer.
 */

module issue_port #(
    parameter NR_ENTRIES = tortoise_pkg::INSTR_PER_FETCH
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* load a group of decoded instructions */
    input   logic   instr_valid_i,
    output  logic   instr_load_o,
    input   tortoise_pkg::scoreboard_entry_t [NR_ENTRIES-1:0]   instr_i,

    /* pop only one each time */
    input   logic   issue_pop_i,
    output  logic   issue_valid_o,
    output  tortoise_pkg::scoreboard_entry_t    issue_instr_o
);

    import tortoise_pkg::scoreboard_entry_t;

    /* We store the new group of instructions in a FIFO. */
    scoreboard_entry_t [NR_ENTRIES-1:0] instr_queue;
    logic   next_valid;             /* whether the next entry to pop is valid */

    assign  issue_instr_o   = instr_queue[0];
    assign  issue_valid_o   = instr_queue[0].valid;
    assign  next_valid      = instr_queue[1].valid;
    /* Load a new group if there is about to be no valid entry in the queue */
    assign  instr_load_o    = instr_valid_i &
                            (~issue_valid_o | (~next_valid & issue_pop_i));

    always_ff @(posedge clk_i or negedge rst_ni) begin: load_and_pop
        if (rst_ni == 1'b0 || flush_i == 1'b1) begin
            instr_queue <= '0;
        end else if (!debug_mode_i) begin
            /* Note, load and pop could happen at the same time. */
            if (instr_load_o) begin         /* load */
                instr_queue <= instr_i;
            end else if (issue_pop_i) begin /* pop/shift */
                instr_queue[NR_ENTRIES-2:0] <= instr_queue[NR_ENTRIES-1:1];
                instr_queue[NR_ENTRIES-1]   <= scoreboard_entry_t'(0);
            end
        end
    end: load_and_pop
endmodule: issue_port
