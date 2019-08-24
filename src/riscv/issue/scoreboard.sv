/*
 * File: scoreboard.sv
 * Desc: ScoreBoard to manipulate the processes of execution and commit
 *
 * Auth: QuanZhao
 * Date: Aug-22-2019
 *
 */

module scoreboard #(
    parameter NR_ENTRIES = tortoise_pkg::SB_ENTRIES /* must be a power of 2 */
) (
    input   logic   clk_i, rst_ni, flush_i, debug_mode_i,

    /* issue port from the decode stage */
    input   logic   issue_req_i,
    output  logic   issue_ack_o,
    input   tortoise_pkg::scoreboard_entry_t    issue_instr_i,

    /* Operands of the issued instruction might come from the register file. */
    input   riscv_pkg::data_t           rs1_value_i, rs2_value_i,
    output  tortoise_pkg::sbreg_t       rs1_o, rs2_o,

    /* Execution ports exchange data and results with the execution units. */
    input   logic   alu_ready_i, branch_ready_i, csr_ready_i, lsu_ready_i,
    output  logic   alu_valid_o, branch_valid_o, csr_valid_o, lsu_valid_o,
    output  tortoise_pkg::fu_data_t     alu_data_o, branch_data_o,
                                        csr_data_o, lsu_data_o,

    input   logic   alu_result_valid_i, branch_result_valid_i,
                    csr_result_valid_i, lsu_result_valid_i,
    output  logic   alu_result_ready_o, branch_result_ready_o,
                    csr_result_ready_o, lsu_result_ready_o,
    input   tortoise_pkg::fu_result_t   alu_result_i, branch_result_i,
                                        csr_result_i, lsu_result_i,

    /* commit port to the commit stage */
    input   logic   commit_ack_i,
    output  logic   commit_req_o,
    output  tortoise_pkg::scoreboard_entry_t    commit_instr_o
);

    import tortoise_pkg::*;
    //import tortoise_pkg::scoreboard_entry_t;
    //import tortoise_pkg::fu_data_t;
    import riscv_pkg::data_t;

    localparam  INDEX_BITS  = $clog2(NR_ENTRIES);
    /*
     * We don't use a tradtional FIFO to represent the scoreboard, so that more
     * than one instructions could be issued or commited at a time in the
     * future.
     */
    scoreboard_entry_t [NR_ENTRIES-1:0] sbqueue;
    logic [INDEX_BITS-1:0]              issue_idx, commit_idx;
    /* We also need to track the execution state of each entry, in order to
     * avoid executing the instruction in process again. */
    logic [NR_ENTRIES-1:0]              in_execution;

    /*
     * First to collect and classify the operations and state of each scoreboard
     * entry, so each kind of operation could be handled individually which also
     * provides a way to avoiding structual hazards.
     */
    fu_data_t   [NR_ENTRIES-1:0]        operations;
    logic       [NR_ENTRIES-1:0]        ready_to_alu, ready_to_branch,
                                        ready_to_csr, ready_to_lsu;

    /* Test whether the unsolved operands match the execution results. */
    logic       [NR_ENTRIES-1:0]        alu_result_match_rs1,
                                        branch_result_match_rs1,
                                        csr_result_match_rs1,
                                        lsu_result_match_rs1;

    logic       [NR_ENTRIES-1:0]        alu_result_match_rs2,
                                        branch_result_match_rs2,
                                        csr_result_match_rs2,
                                        lsu_result_match_rs2;
    /* The information of all the 'rd' from the scoreboard and execution results
     * are also collected to avoid data WAW hazards. */
    logic       [NR_SBREGS-1:0]         rd_bitmap, rd_valid;
    data_t      [NR_SBREGS-1:0]         rd_value;

    always_comb begin: collect_information
        rd_bitmap   = '0;
        rd_valid    = '0;
        for (int i = 0; i < NR_ENTRIES; i++) begin: from_scoreboard
            scoreboard_entry_t sbe  = sbqueue[i];

            /*
             * It is a bit complex to decide which entry is ready to execute:
             * 1. the entry is valid without an exception;
             * 2. it is not in execution yet;
             * 3. all the operands are ready;
             * 4. the result is unknown.
             */
            logic ready_to_execute  = sbe.valid & ~in_execution[i] &
                ~sbe.ex.valid & ~sbe.result.valid &
                sbe.operand1.valid & sbe.operand2.valid;

            /* collect the operations and states */
            operations[i]       = '{sbe.index, sbe.fu, sbe.op,
                                sbe.operand1.value, sbe.operand2.value};
            ready_to_alu[i]     = (sbe.fu == FU_ALU)    & ready_to_execute;
            ready_to_branch[i]  = (sbe.fu == FU_BRANCH) & ready_to_execute;
            ready_to_csr[i]     = (sbe.fu == FU_CSR)    & ready_to_execute;
            ready_to_lsu[i]     = (sbe.fu inside {FU_LOAD, FU_STORE}) &
                                ready_to_execute;

            /* the RAW data dependence information */
            alu_result_match_rs1[i]     = ~sbe.operand1.valid &
                (sbe.operand1.regno == alu_result_i.rd);
            alu_result_match_rs2[i]     = ~sbe.operand2.valid &
                (sbe.operand2.regno == alu_result_i.rd);

            branch_result_match_rs1[i]  = ~sbe.operand1.valid &
                (sbe.operand1.regno == branch_result_i.rd);
            branch_result_match_rs2[i]  = ~sbe.operand2.valid &
                (sbe.operand2.regno == branch_result_i.rd);

            csr_result_match_rs1[i]     = ~sbe.operand1.valid &
                (sbe.operand1.regno == csr_result_i.rd);
            csr_result_match_rs2[i]     = ~sbe.operand2.valid &
                (sbe.operand2.regno == csr_result_i.rd);

            lsu_result_match_rs1[i]     = ~sbe.operand1.valid &
                (sbe.operand1.regno == lsu_result_i.rd);
            lsu_result_match_rs2[i]     = ~sbe.operand2.valid &
                (sbe.operand2.regno == lsu_result_i.rd);
            /* collect all the 'rd' in the scoreboard */
            rd_bitmap[sbe.result.regno] = sbe.valid;
            rd_valid[sbe.result.regno]  = sbe.valid & sbe.result.valid;
            rd_value[sbe.result.regno]  = sbe.result.value;
        end: from_scoreboard

        /* The execution results are of higher priority. */
        if (alu_result_valid_i & alu_result_ready_o) begin: from_alu_result
            rd_valid[alu_result_i.rd]       = 1'b1;
            rd_value[alu_result_i.rd]       = alu_result_i.result;
        end: from_alu_result

        if (branch_result_valid_i & branch_result_ready_o)
        begin: from_branch_result
            rd_valid[branch_result_i.rd]    = 1'b1;
            rd_value[branch_result_i.rd]    = branch_result_i.result;
        end: from_branch_result

        if (csr_result_valid_i & csr_result_ready_o) begin: from_csr_result
            rd_valid[csr_result_i.rd]       = 1'b1;
            rd_value[csr_result_i.rd]       = csr_result_i.result;
        end: from_csr_result

        if (lsu_result_valid_i & lsu_result_ready_o) begin: from_lsu_result
            rd_valid[lsu_result_i.rd]       = 1'b1;
            rd_value[lsu_result_i.rd]       = lsu_result_i.result;
        end: from_lsu_result
    end: collect_information

    /*
     * Since all the necessary data has been collected, we start to handle how
     * they are exchanged through 3 kinds of ports. Note that all the sending
     * signals are controlled through combinational logic, while receiving
     * signals sequential logic.
     */

    /* execution ports */
    /* For now, we only execute one instruction at a time for each functional
     * unit, so each unit needs only one index. */
    logic [INDEX_BITS-1:0]  alu_idx, branch_idx, csr_idx, lsu_idx;
    logic [INDEX_BITS-1:0]  alu_result_idx, branch_result_idx,
                            csr_result_idx, lsu_result_idx;

    /*
     * Watch this, we start from the entry to commit to make sure the oldest
     * entry have the highest priority to execute. This is important, since the
     * entries are commited in order, an waiting-to-process new entry might
     * block the waiting-to-process old one to execute while the latter prevents
     * the former to commit, which causes a deadlock.
     *
     * Don't forget the case where there is no instruction ready to execute.
     */
    find_first_one #(               /* alu */
        .WIDTH(NR_ENTRIES)
    ) alu_arbitor (
        .data_i(ready_to_alu), .start_i(commit_idx), .index_o(alu_idx),
        .valid_one_o(alu_valid_o)
    );
    assign  alu_data_o              = operations[alu_idx];

    assign  alu_result_idx          = alu_result_i.index;
    assign  alu_result_ready_o      = in_execution[alu_result_idx] &
        sbqueue[alu_result_idx].valid & ~sbqueue[alu_result_idx].result.valid;

    find_first_one #(               /* branch */
        .WIDTH(NR_ENTRIES)
    ) branch_arbitor (
        .data_i(ready_to_branch), .start_i(commit_idx), .index_o(branch_idx),
        .valid_one_o(branch_valid_o)
    );
    assign  branch_data_o           = operations[branch_idx];

    assign  branch_result_idx       = branch_result_i.index;
    assign  branch_result_ready_o   = in_execution[branch_result_idx] &
        sbqueue[branch_result_idx].valid &
        ~sbqueue[branch_result_idx].result.valid;

    find_first_one #(               /* csr */
        .WIDTH(NR_ENTRIES)
    ) csr_arbitor (
        .data_i(ready_to_csr), .start_i(commit_idx), .index_o(csr_idx),
        .valid_one_o(csr_valid_o)
    );
    assign  csr_data_o              = operations[csr_idx];

    assign  csr_result_idx          = csr_result_i.index;
    assign  csr_result_ready_o      = in_execution[csr_result_idx] &
        sbqueue[csr_result_idx].valid & ~sbqueue[csr_result_idx].result.valid;

    find_first_one #(               /* lsu */
        .WIDTH(NR_ENTRIES)
    ) lsu_arbitor (
        .data_i(ready_to_lsu), .start_i(commit_idx), .index_o(lsu_idx),
        .valid_one_o(lsu_valid_o)
    );
    assign  lsu_data_o              = operations[lsu_idx];

    assign  lsu_result_idx          = lsu_result_i.index;
    assign  lsu_result_ready_o      = in_execution[lsu_result_idx] &
        sbqueue[lsu_result_idx].valid & ~sbqueue[lsu_result_idx].result.valid;

    /* commit port */
    /* If the result of the entry to commit is known or an exception exists in
     * the entry, then it is ready to commit. */
    assign  commit_instr_o  = sbqueue[commit_idx];
    assign  commit_req_o    = commit_instr_o.valid &
        (commit_instr_o.ex.valid | commit_instr_o.result.valid);

    /* issue port */
    /* If there is an empty entry and no 'rd' conflict (except for x0), issue
     * the instruction into the scoreboard. */
    logic   full        = sbqueue[issue_idx].valid;
    logic   rd_conflict = | ((NR_SBREGS'(1) << issue_instr_i.result.regno) &
                            {rd_bitmap[NR_SBREGS-1:1], 1'b0});
    assign  issue_ack_o = issue_req_i &  ~full & ~rd_conflict;

    /*
     * Now try to figure out the exact values of the operands in the instruction
     * to issue. There are 4 cases:
     * 1. If the value of the operand is valid, no more action is needed;
     * 2. If one valid 'rd' or execution result matches the operand, use it;
     * 3. If one non-valid 'rd' in the scoreboard matches the operand, no more
     * action is needed;
     * 4. Use the value from the register file.
     */
    /* First, we always read the register file even not needed */
    assign  rs1_o       = issue_instr_i.operand1.regno;
    assign  rs2_o       = issue_instr_i.operand2.regno;

    /* look up the matched 'rd' in the scoreboard */
    scoreboard_entry_t  issued_instr;
    always_comb begin
        issued_instr    = issue_instr_i;

        if (~issue_instr_i.operand1.valid) begin: lookup_operand1
            if(rd_bitmap[rs1_o] == 1'b1) begin
                /* 'rs1' conflicts with the 'rd' list ... */
                if (rd_valid[rs1_o] == 1'b1) begin
                    /* however, the value of the corresponding 'rd' is known. */
                    issued_instr.operand1.valid = 1'b1;
                    issued_instr.operand1.value = rd_value[rs1_o];
                end
            end else begin
                /* no conflicts at all, read value from the register file */
                issued_instr.operand1.valid = 1'b1;
                issued_instr.operand1.value = rs1_value_i;
            end
        end: lookup_operand1

        if (~issue_instr_i.operand2.valid) begin: lookup_operand2
            if(rd_bitmap[rs2_o] == 1'b1) begin
                /* 'rs2' conflicts with the 'rd' list ... */
                if (rd_valid[rs2_o] == 1'b1) begin
                    /* however, the value of the corresponding 'rd' is known. */
                    issued_instr.operand2.valid = 1'b1;
                    issued_instr.operand2.value = rd_value[rs2_o];
                end
            end else begin
                /* no conflicts at all, read value from the register file */
                issued_instr.operand2.valid = 1'b1;
                issued_instr.operand2.value = rs2_value_i;
            end
        end: lookup_operand2
    end

    /* Note that there are 4 (not 3) sources to update the scoreboard: issue
     * acknowlegement, commit acknowlegement, operation-data acknowlegements and
     * operation-result acknowlegements. */
    always_ff @(posedge clk_i or negedge rst_ni) begin: update_scoreboard
        if (rst_ni == 1'b0 || flush_i == 1'b1) begin
            sbqueue         <= '0;
            in_execution    <= '0;
            issue_idx       <= '0;
            commit_idx      <= '0;
        end else begin
            /* issue port */
            if (issue_ack_o) begin
                in_execution[issue_idx] <= 1'b0;        /* prepare to execute */
                sbqueue[issue_idx]      <= issued_instr;
                issue_idx   <= issue_idx + INDEX_BITS'(1);
            end

            /* commit port */
            if (commit_ack_i) begin
                sbqueue[commit_idx].valid   <= 1'b0;
                commit_idx  <= commit_idx + INDEX_BITS'(1);
            end

            /* execution ports */
            if (alu_valid_o & alu_ready_i)      /* alu */
                in_execution[alu_idx]   <= 1'b1;

            /* alu result */
            if (alu_result_valid_i & alu_result_ready_o) begin
                in_execution[alu_result_idx]    <= 1'b0;
                sbqueue[alu_result_idx].result.valid    <= 1'b1;
                sbqueue[alu_result_idx].result.value    <= alu_result_i.result;
                if (alu_result_i.ex.valid)
                    sbqueue[alu_result_idx].ex          <= alu_result_i.ex;

                /* also update the source registers that depend on the result */
                for (int i = 0; i < NR_ENTRIES; i++) begin
                    if (alu_result_match_rs1[i]) begin
                        sbqueue[i].operand1.value   <= alu_result_i.result;
                        sbqueue[i].operand1.valid   <= 1'b1;
                    end

                    if (alu_result_match_rs2[i]) begin
                        sbqueue[i].operand2.value   <= alu_result_i.result;
                        sbqueue[i].operand2.valid   <= 1'b1;
                    end
                end
            end

            if (branch_valid_o & branch_ready_i)    /* branch */
                in_execution[branch_idx]    <= 1'b1;

            /* branch result */
            if (branch_result_valid_i & branch_result_ready_o) begin
                in_execution[branch_result_idx]   <= 1'b0;
                sbqueue[branch_result_idx].result.valid <= 1'b1;
                sbqueue[branch_result_idx].result.value <= branch_result_i.result;
                if (branch_result_i.ex.valid)
                    sbqueue[branch_result_idx].ex       <= branch_result_i.ex;

                /* also update the source registers that depend on the result */
                for (int i = 0; i < NR_ENTRIES; i++) begin
                    if (branch_result_match_rs1[i]) begin
                        sbqueue[i].operand1.value   <= branch_result_i.result;
                        sbqueue[i].operand1.valid   <= 1'b1;
                    end

                    if (branch_result_match_rs2[i]) begin
                        sbqueue[i].operand2.value   <= branch_result_i.result;
                        sbqueue[i].operand2.valid   <= 1'b1;
                    end
                end
            end

            if (csr_valid_o & csr_ready_i)      /* csr */
                in_execution[csr_idx]   <= 1'b1;

            /* csr result */
            if (csr_result_valid_i & csr_result_ready_o) begin
                in_execution[csr_result_idx]    <= 1'b0;
                sbqueue[csr_result_idx].result.valid    <= 1'b1;
                sbqueue[csr_result_idx].result.value    <= csr_result_i.result;
                if (csr_result_i.ex.valid)
                    sbqueue[csr_result_idx].ex          <= csr_result_i.ex;

                /* also update the source registers that depend on the result */
                for (int i = 0; i < NR_ENTRIES; i++) begin
                    if (csr_result_match_rs1[i]) begin
                        sbqueue[i].operand1.value   <= csr_result_i.result;
                        sbqueue[i].operand1.valid   <= 1'b1;
                    end

                    if (csr_result_match_rs2[i]) begin
                        sbqueue[i].operand2.value   <= csr_result_i.result;
                        sbqueue[i].operand2.valid   <= 1'b1;
                    end
                end
            end

            if (lsu_valid_o & lsu_ready_i)      /* lsu */
                in_execution[lsu_idx]   <= 1'b1;

            /* lsu result */
            if (lsu_result_valid_i & lsu_result_ready_o) begin
                in_execution[lsu_result_idx]    <= 1'b0;
                sbqueue[lsu_result_idx].result.valid    <= 1'b1;
                sbqueue[lsu_result_idx].result.value    <= lsu_result_i.result;
                if (lsu_result_i.ex.valid)
                    sbqueue[lsu_result_idx].ex          <= lsu_result_i.ex;

                /* also update the source registers that depend on the result */
                for (int i = 0; i < NR_ENTRIES; i++) begin
                    if (lsu_result_match_rs1[i]) begin
                        sbqueue[i].operand1.value   <= lsu_result_i.result;
                        sbqueue[i].operand1.valid   <= 1'b1;
                    end

                    if (lsu_result_match_rs2[i]) begin
                        sbqueue[i].operand2.value   <= lsu_result_i.result;
                        sbqueue[i].operand2.valid   <= 1'b1;
                    end
                end
            end
        end
    end: update_scoreboard

endmodule: scoreboard
