/*
 * File: syscofig.svh
 * Desc: user configurations for the whole system
 *
 * Auth: QuanZhao
 * Date: Jul-04-2019
 *
 * For now, only systemverilog macro definitions are allowed here.
 */

`ifndef _SYSCONFIG_SVH_
`define _SYSCONFIG_SVH_

/*********************************** RISC-V ***********************************/
`define CONFIG_RV64I_SUPPORT    1   /* for now, you must not change it */

/***************************** Instruction Fetch ******************************/
`define CONFIG_INSTR_PER_FETCH  4   /* the number of instruction per fetch */

`define CONFIG_RAS_DEPTH        8   /* the depth of Return Address Stack */
`define CONFIG_BHT_ENTRIES      1024    /* branch history: taken or not */
`define CONFIG_BTB_ENTRIES      1024    /* branch target buffer */

`define CONFIG_IFQ_DEPTH        8   /* the depth of instruction fetch queue */

/********************************* ScoreBoard *********************************/
`define CONFIG_SB_ENTRIES       8   /* the number of Scoreboard entries */

/*********************************** Commit ***********************************/
`define CONFIG_GPREG_READ_PORTS     3   /* GP register read ports */
`define CONFIG_GPREG_WRITE_PORTS    1   /* GP register write ports */

/************************************ AXI *************************************/
`define CONFIG_AXI_ID_WIDTH     4
`define CONFIG_AXI_USER_WIDTH   4

`define CONFIG_AXI_ADDR_WIDTH   64
`define CONFIG_AXI_DATA_WIDTH   64


`define CONFIG_AXI_MASTERS      3   /* random, should not be larger than 15 */
`define CONFIG_AXI_SLAVES       8   /* random, should not be larger than 15 */

`endif  /* _SYSCONFIG_SVH_ */
