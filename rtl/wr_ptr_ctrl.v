//=============================================================================
// 模块名称: wr_ptr_ctrl
// 功能描述: 写指针控制模块 (Write Pointer Controller)
//           - 管理写指针的递增和二进制/格雷码转换
//           - 生成满标志(full)和半满标志(half_full)
//           - full在写时钟域生成，确保实时阻止满写
//
// 关键设计:
//   指针位宽 = ADDR_WIDTH + 1，多出的MSB用于区分空/满
//   满判断：写格雷码指针的高2位与同步后读格雷码指针的高2位不同，
//           其余低位相同 → 表示写指针比读指针多走了一整圈(即FIFO满)
//   半满：在写时钟域将同步后的读格雷码指针转回二进制，
//         计算存储量 = wr_bin - rd_bin_sync，判断是否 >= FIFO_DEPTH/2
//
// 作者:     IC Design Engineer
// 日期:     2026-03-09
//=============================================================================

module wr_ptr_ctrl #(
    parameter ADDR_WIDTH = 6            // 地址位宽 (Address width)
)(
    input  wire                    clk_wr,       // 写时钟 (Write clock)
    input  wire                    rst_n,         // 异步低电平复位 (Async active-low reset)
    input  wire                    wr_en,         // 写使能 (Write enable)
    input  wire [ADDR_WIDTH:0]     rd_gray_sync,  // 同步后的读格雷码指针
                                                   // (Read Gray ptr synchronized to wr clk domain)

    output wire [ADDR_WIDTH:0]     wr_bin_ptr,    // 写指针(二进制) (Write pointer, binary)
    output wire [ADDR_WIDTH:0]     wr_gray_ptr,   // 写指针(格雷码) (Write pointer, Gray code)
    output wire [ADDR_WIDTH-1:0]   wr_addr,       // 写地址 (Write address, lower bits)
    output wire                    full,           // 满标志 (Full flag)
    output wire                    half_full       // 半满标志 (Half-full flag)
);

    //=========================================================================
    // 参数定义 (Parameter Definitions)
    //=========================================================================
    localparam PTR_WIDTH  = ADDR_WIDTH + 1;       // 指针位宽 = 7
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;      // FIFO深度 = 64
    localparam HALF_DEPTH = FIFO_DEPTH >> 1;      // 半深度 = 32

    //=========================================================================
    // 内部信号 (Internal Signals)
    //=========================================================================
    reg  [PTR_WIDTH-1:0] wr_bin_reg;              // 写指针二进制寄存器
    reg  [PTR_WIDTH-1:0] wr_gray_reg;             // 写指针格雷码寄存器
    wire [PTR_WIDTH-1:0] wr_bin_next;             // 下一个写指针(二进制)
    wire [PTR_WIDTH-1:0] wr_gray_next;            // 下一个写指针(格雷码)
    wire                 wr_valid;                 // 有效写操作标志

    // 用于半满计算的信号
    wire [PTR_WIDTH-1:0] rd_bin_sync;             // 同步后读指针转回二进制
    wire [PTR_WIDTH-1:0] data_count;              // 当前存储数据量

    //=========================================================================
    // 有效写操作判断 (Valid Write Operation)
    // 只有在wr_en有效且FIFO未满时才执行写操作
    //=========================================================================
    assign wr_valid = wr_en && !full;

    //=========================================================================
    // 写指针递增逻辑 (Write Pointer Increment Logic)
    //=========================================================================
    assign wr_bin_next  = wr_valid ? (wr_bin_reg + 1'b1) : wr_bin_reg;
    assign wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);  // Binary → Gray

    always @(posedge clk_wr or negedge rst_n) begin
        if (!rst_n) begin
            wr_bin_reg  <= {PTR_WIDTH{1'b0}};
            wr_gray_reg <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_bin_reg  <= wr_bin_next;
            wr_gray_reg <= wr_gray_next;
        end
    end

    //=========================================================================
    // 输出赋值 (Output Assignments)
    //=========================================================================
    assign wr_bin_ptr  = wr_bin_reg;
    assign wr_gray_ptr = wr_gray_reg;
    assign wr_addr     = wr_bin_reg[ADDR_WIDTH-1:0];  // 低6位作为RAM地址

    //=========================================================================
    // 满标志生成 (Full Flag Generation)
    //
    // 格雷码满判断条件(经典3条件法):
    //   1. 写格雷码最高位(MSB)   != 同步后读格雷码最高位
    //   2. 写格雷码次高位(MSB-1) != 同步后读格雷码次高位
    //   3. 写格雷码其余低位      == 同步后读格雷码其余低位
    //
    // 原理：在格雷码编码下，当写指针比读指针恰好多走一整圈(FIFO_DEPTH)时，
    //       二进制的MSB不同 → 映射到格雷码的高2位不同，低位相同
    //=========================================================================
    assign full = (wr_gray_reg[PTR_WIDTH-1]   != rd_gray_sync[PTR_WIDTH-1])   &&  // MSB不同
                  (wr_gray_reg[PTR_WIDTH-2]   != rd_gray_sync[PTR_WIDTH-2])   &&  // 次高位不同
                  (wr_gray_reg[PTR_WIDTH-3:0] == rd_gray_sync[PTR_WIDTH-3:0]);    // 低位相同

    //=========================================================================
    // 格雷码→二进制转换(用于半满计算)
    // 将同步到写时钟域的读格雷码指针转回二进制
    //=========================================================================
    gray_code_conv #(
        .WIDTH(PTR_WIDTH)
    ) u_gray2bin_rd (
        .bin_in   ({PTR_WIDTH{1'b0}}),    // 未使用的bin→gray输入
        .gray_in  (rd_gray_sync),          // 格雷码输入：同步后的读指针
        .gray_out (),                      // 未使用的gray输出
        .bin_out  (rd_bin_sync)            // 二进制输出：转换后的读指针
    );

    //=========================================================================
    // 半满标志生成 (Half-Full Flag Generation)
    //
    // 计算当前存储量 = 写指针(二进制) - 读指针(二进制，同步+解码后)
    // 当存储量 >= HALF_DEPTH(32) 时，half_full置位
    //
    // 注意：由于同步延迟(2-3个写时钟周期)，实际存储量可能比计算值
    //       略多，因此half_full是保守估计(可能稍晚拉高)，不影响正确性
    //=========================================================================
    assign data_count = wr_bin_reg - rd_bin_sync;
    assign half_full  = (data_count >= HALF_DEPTH);

endmodule
