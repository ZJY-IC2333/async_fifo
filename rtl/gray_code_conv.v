//=============================================================================
// 模块名称: gray_code_conv
// 功能描述: 格雷码转换器 (Gray Code Converter)
//           提供二进制→格雷码 和 格雷码→二进制 两种转换功能
//           采用纯组合逻辑实现，可综合
//
// 转换原理:
//   Binary → Gray:  gray[i] = bin[i] ^ bin[i+1], gray[MSB] = bin[MSB]
//                    简化公式: gray = bin ^ (bin >> 1)
//   Gray → Binary:  bin[MSB] = gray[MSB]
//                    bin[i] = bin[i+1] ^ gray[i]  (从高位到低位逐位异或)
//
// 作者:     IC Design Engineer
// 日期:     2026-03-09
//=============================================================================

module gray_code_conv #(
    parameter WIDTH = 7                 // 码字位宽 (Code word width)
)(
    input  wire [WIDTH-1:0] bin_in,     // 二进制输入 (Binary input)
    input  wire [WIDTH-1:0] gray_in,    // 格雷码输入 (Gray code input)
    output wire [WIDTH-1:0] gray_out,   // 格雷码输出 (Gray code output)
    output wire [WIDTH-1:0] bin_out     // 二进制输出 (Binary output)
);

    //=========================================================================
    // 二进制 → 格雷码 (Binary to Gray Code)
    // 公式: gray = bin XOR (bin >> 1)
    // 原理: 相邻二进制数转换后只有1bit不同，适合跨时钟域传输
    //=========================================================================
    assign gray_out = bin_in ^ (bin_in >> 1);

    //=========================================================================
    // 格雷码 → 二进制 (Gray Code to Binary)
    // 原理: 从最高位开始，逐位异或还原二进制值
    // bin[N-1] = gray[N-1]
    // bin[i]   = bin[i+1] ^ gray[i], for i = N-2 down to 0
    //=========================================================================
    // 使用generate循环实现可参数化的转换
    genvar i;

    assign bin_out[WIDTH-1] = gray_in[WIDTH-1];

    generate
        for (i = WIDTH-2; i >= 0; i = i - 1) begin : gray2bin_loop
            assign bin_out[i] = bin_out[i+1] ^ gray_in[i];
        end
    endgenerate

endmodule
