//=============================================================================
// 模块名称: fifo_mem
// 功能描述: 双端口RAM存储体 (Dual-Port RAM for FIFO Storage)
//           写端口由clk_wr驱动，读端口由clk_rd驱动
//           仅在wr_en有效且FIFO未满时执行写操作
//           读端口采用组合逻辑输出（异步读），提升时序性能
// 作者:     IC Design Engineer
// 日期:     2026-03-09
//=============================================================================

module fifo_mem #(
    parameter DATA_WIDTH = 32,          // 数据位宽 (Data width)
    parameter ADDR_WIDTH = 6            // 地址位宽 (Address width)
)(
    input  wire                    clk_wr,   // 写时钟 (Write clock)
    input  wire                    clk_rd,   // 读时钟 (Read clock) - 保留用于寄存器输出模式
    input  wire                    wr_en,    // 写使能 (Write enable)
    input  wire                    full,     // 满标志 (Full flag，防止满写)
    input  wire [ADDR_WIDTH-1:0]   wr_addr,  // 写地址 (Write address)
    input  wire [ADDR_WIDTH-1:0]   rd_addr,  // 读地址 (Read address)
    input  wire [DATA_WIDTH-1:0]   din,      // 写数据 (Write data)
    output wire [DATA_WIDTH-1:0]   dout      // 读数据 (Read data)
);

    //=========================================================================
    // 存储阵列定义 (Memory Array Definition)
    // 深度 = 2^ADDR_WIDTH = 64，宽度 = DATA_WIDTH = 32
    //=========================================================================
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;  // 2^6 = 64
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    //=========================================================================
    // 写操作 (Write Operation)
    // 条件：wr_en有效 且 FIFO未满
    // 在写时钟上升沿写入数据
    //=========================================================================
    always @(posedge clk_wr) begin
        if (wr_en && !full) begin
            mem[wr_addr] <= din;
        end
    end

    //=========================================================================
    // 读操作 (Read Operation)
    // 采用组合逻辑读取（异步读），数据直接通过地址索引输出
    // 优点：减少一拍延迟，读数据在地址变化后立即有效
    // 注意：综合工具会将其推断为分布式RAM或异步读RAM
    //=========================================================================
    assign dout = mem[rd_addr];

endmodule
