//=============================================================================
// 模块名称: async_fifo
// 功能描述: 异步FIFO顶层模块 (Asynchronous FIFO Top-Level Module)
//           集成所有子模块：写指针控制、读指针控制、格雷码转换、
//           跨时钟域同步器、双端口RAM存储体
// 作者:     IC Design Engineer
// 日期:     2026-03-09
// 参数:
//   DATA_WIDTH - 数据位宽，默认32bit
//   ADDR_WIDTH - 地址位宽，默认6bit (深度=2^6=64)
//=============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 32,          // 数据位宽 (Data width)
    parameter ADDR_WIDTH = 6            // 地址位宽 (Address width), 深度 = 2^ADDR_WIDTH
)(
    // ========== 写端口信号 (Write Port Signals) ==========
    input  wire                  clk_wr,     // 写时钟，100MHz (Write clock)
    input  wire                  rst_n,       // 异步低电平复位 (Async active-low reset)
    input  wire                  wr_en,       // 写使能 (Write enable)
    input  wire [DATA_WIDTH-1:0] din,         // 写数据输入 (Write data input)
    output wire                  full,        // 写满标志 (Full flag)
    output wire                  half_full,   // 半满标志 (Half-full flag, >=32 entries)

    // ========== 读端口信号 (Read Port Signals) ==========
    input  wire                  clk_rd,     // 读时钟，50MHz (Read clock)
    input  wire                  rd_en,       // 读使能 (Read enable)
    output wire [DATA_WIDTH-1:0] dout,        // 读数据输出 (Read data output)
    output wire                  empty        // 读空标志 (Empty flag)
);

    //=========================================================================
    // 内部信号定义 (Internal Signal Declarations)
    //=========================================================================

    // 指针位宽 = ADDR_WIDTH + 1，多出1位MSB用于区分空/满
    // Pointer width = ADDR_WIDTH + 1, extra MSB for full/empty distinction
    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    // ---------- 写指针相关信号 ----------
    wire [PTR_WIDTH-1:0] wr_bin_ptr;      // 写指针（二进制） (Write pointer, binary)
    wire [PTR_WIDTH-1:0] wr_gray_ptr;     // 写指针（格雷码） (Write pointer, Gray code)
    wire [ADDR_WIDTH-1:0] wr_addr;        // 写地址（取低ADDR_WIDTH位）(Write address)

    // ---------- 读指针相关信号 ----------
    wire [PTR_WIDTH-1:0] rd_bin_ptr;      // 读指针（二进制） (Read pointer, binary)
    wire [PTR_WIDTH-1:0] rd_gray_ptr;     // 读指针（格雷码） (Read pointer, Gray code)
    wire [ADDR_WIDTH-1:0] rd_addr;        // 读地址（取低ADDR_WIDTH位）(Read address)

    // ---------- 跨时钟域同步后的指针 ----------
    wire [PTR_WIDTH-1:0] wr_gray_sync;    // 写格雷码指针同步到读时钟域
                                           // (Write Gray ptr synchronized to rd clk domain)
    wire [PTR_WIDTH-1:0] rd_gray_sync;    // 读格雷码指针同步到写时钟域
                                           // (Read Gray ptr synchronized to wr clk domain)

    //=========================================================================
    // 子模块实例化 (Sub-module Instantiation)
    //=========================================================================

    // -------- 写指针控制模块 --------
    // 负责：写指针递增、二进制/格雷码生成、full/half_full判断
    wr_ptr_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_wr_ptr_ctrl (
        .clk_wr        (clk_wr),
        .rst_n         (rst_n),
        .wr_en         (wr_en),
        .rd_gray_sync  (rd_gray_sync),    // 从读时钟域同步过来的读指针
        .wr_bin_ptr    (wr_bin_ptr),
        .wr_gray_ptr   (wr_gray_ptr),
        .wr_addr       (wr_addr),
        .full          (full),
        .half_full     (half_full)
    );

    // -------- 读指针控制模块 --------
    // 负责：读指针递增、二进制/格雷码生成、empty判断
    rd_ptr_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_rd_ptr_ctrl (
        .clk_rd        (clk_rd),
        .rst_n         (rst_n),
        .rd_en         (rd_en),
        .wr_gray_sync  (wr_gray_sync),    // 从写时钟域同步过来的写指针
        .rd_bin_ptr    (rd_bin_ptr),
        .rd_gray_ptr   (rd_gray_ptr),
        .rd_addr       (rd_addr),
        .empty         (empty)
    );

    // -------- 写指针格雷码 → 读时钟域同步器 --------
    // 将wr_gray_ptr从clk_wr域同步到clk_rd域，用于empty判断
    sync_2ff #(
        .WIDTH(PTR_WIDTH)
    ) u_sync_wr2rd (
        .clk     (clk_rd),               // 目标时钟域：读时钟
        .rst_n   (rst_n),
        .din     (wr_gray_ptr),           // 输入：写时钟域的格雷码指针
        .dout    (wr_gray_sync)           // 输出：同步后的写格雷码指针
    );

    // -------- 读指针格雷码 → 写时钟域同步器 --------
    // 将rd_gray_ptr从clk_rd域同步到clk_wr域，用于full/half_full判断
    sync_2ff #(
        .WIDTH(PTR_WIDTH)
    ) u_sync_rd2wr (
        .clk     (clk_wr),               // 目标时钟域：写时钟
        .rst_n   (rst_n),
        .din     (rd_gray_ptr),           // 输入：读时钟域的格雷码指针
        .dout    (rd_gray_sync)           // 输出：同步后的读格雷码指针
    );

    // -------- 双端口RAM存储体 --------
    // 写端口：clk_wr驱动，读端口：clk_rd驱动
    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo_mem (
        .clk_wr   (clk_wr),
        .clk_rd   (clk_rd),
        .wr_en    (wr_en),
        .full     (full),
        .wr_addr  (wr_addr),
        .rd_addr  (rd_addr),
        .din      (din),
        .dout     (dout)
    );

endmodule
