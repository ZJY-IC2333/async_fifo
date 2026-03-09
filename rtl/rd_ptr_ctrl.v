//=============================================================================
// 模块名称: rd_ptr_ctrl
// 功能描述: 读指针控制模块 (Read Pointer Controller)
//           - 管理读指针的递增和二进制/格雷码转换
//           - 生成空标志(empty)
//           - empty在读时钟域生成，确保实时阻止空读
//
// 关键设计:
//   空判断：读格雷码指针 == 同步后的写格雷码指针 → FIFO为空
//   这是因为当读追上写时，两个指针值完全相同(包括MSB)
//
// 作者:     IC Design Engineer
// 日期:     2026-03-09
//=============================================================================

module rd_ptr_ctrl #(
    parameter ADDR_WIDTH = 6            // 地址位宽 (Address width)
)(
    input  wire                    clk_rd,       // 读时钟 (Read clock)
    input  wire                    rst_n,         // 异步低电平复位 (Async active-low reset)
    input  wire                    rd_en,         // 读使能 (Read enable)
    input  wire [ADDR_WIDTH:0]     wr_gray_sync,  // 同步后的写格雷码指针
                                                   // (Write Gray ptr synchronized to rd clk domain)

    output wire [ADDR_WIDTH:0]     rd_bin_ptr,    // 读指针(二进制) (Read pointer, binary)
    output wire [ADDR_WIDTH:0]     rd_gray_ptr,   // 读指针(格雷码) (Read pointer, Gray code)
    output wire [ADDR_WIDTH-1:0]   rd_addr,       // 读地址 (Read address, lower bits)
    output wire                    empty           // 空标志 (Empty flag)
);

    //=========================================================================
    // 参数定义 (Parameter Definitions)
    //=========================================================================
    localparam PTR_WIDTH = ADDR_WIDTH + 1;        // 指针位宽 = 7

    //=========================================================================
    // 内部信号 (Internal Signals)
    //=========================================================================
    reg  [PTR_WIDTH-1:0] rd_bin_reg;              // 读指针二进制寄存器
    reg  [PTR_WIDTH-1:0] rd_gray_reg;             // 读指针格雷码寄存器
    wire [PTR_WIDTH-1:0] rd_bin_next;             // 下一个读指针(二进制)
    wire [PTR_WIDTH-1:0] rd_gray_next;            // 下一个读指针(格雷码)
    wire                 rd_valid;                 // 有效读操作标志

    //=========================================================================
    // 有效读操作判断 (Valid Read Operation)
    // 只有在rd_en有效且FIFO非空时才执行读操作
    //=========================================================================
    assign rd_valid = rd_en && !empty;

    //=========================================================================
    // 读指针递增逻辑 (Read Pointer Increment Logic)
    //=========================================================================
    assign rd_bin_next  = rd_valid ? (rd_bin_reg + 1'b1) : rd_bin_reg;
    assign rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);  // Binary → Gray

    always @(posedge clk_rd or negedge rst_n) begin
        if (!rst_n) begin
            rd_bin_reg  <= {PTR_WIDTH{1'b0}};
            rd_gray_reg <= {PTR_WIDTH{1'b0}};
        end else begin
            rd_bin_reg  <= rd_bin_next;
            rd_gray_reg <= rd_gray_next;
        end
    end

    //=========================================================================
    // 输出赋值 (Output Assignments)
    //=========================================================================
    assign rd_bin_ptr  = rd_bin_reg;
    assign rd_gray_ptr = rd_gray_reg;
    assign rd_addr     = rd_bin_reg[ADDR_WIDTH-1:0];  // 低6位作为RAM地址

    //=========================================================================
    // 空标志生成 (Empty Flag Generation)
    //
    // 判断条件：读格雷码指针 == 同步后的写格雷码指针
    // 当读追上写时，两者完全相同(包括MSB)，表示FIFO为空
    //
    // 注意：由于同步延迟，实际写指针可能已经前进，
    //       所以empty可能"虚空"(falsely asserted)，
    //       但绝不会"漏空"(missed empty) → 这是安全的保守策略
    //=========================================================================
    assign empty = (rd_gray_reg == wr_gray_sync);

endmodule
