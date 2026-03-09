//=============================================================================
// 模块名称: sync_2ff
// 功能描述: 两级触发器同步器 (2-Stage Flip-Flop Synchronizer)
//           用于跨时钟域(CDC)信号同步，降低亚稳态概率
//
// 工作原理:
//   信号从源时钟域进入目标时钟域时，由于两个时钟异步，
//   第一级触发器(sync_reg1)可能进入亚稳态(Metastability)。
//   经过一个目标时钟周期后，第二级触发器(sync_reg2)采样到
//   已稳定的值，输出给目标时钟域使用。
//
//   亚稳态穿透两级的概率极低(MTBF可达数十年级别)，
//   因此2级同步是工业标准做法。
//
// 关键约束:
//   被同步的信号每次只能有1bit变化(这是使用格雷码的原因)
//
// 作者:     IC Design Engineer
// 日期:     2026-03-09
//=============================================================================

module sync_2ff #(
    parameter WIDTH = 7                 // 同步信号位宽 (Signal width)
)(
    input  wire             clk,        // 目标时钟域时钟 (Destination clock)
    input  wire             rst_n,      // 异步低电平复位 (Async active-low reset)
    input  wire [WIDTH-1:0] din,        // 输入信号(来自源时钟域) (Input from source domain)
    output wire [WIDTH-1:0] dout        // 输出信号(同步后) (Synchronized output)
);

    //=========================================================================
    // 两级同步寄存器 (2-Stage Synchronization Registers)
    //=========================================================================
    reg [WIDTH-1:0] sync_reg1;          // 第一级：可能出现亚稳态 (1st stage: may be metastable)
    reg [WIDTH-1:0] sync_reg2;          // 第二级：输出稳定值 (2nd stage: stable output)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 异步复位：两级寄存器清零
            sync_reg1 <= {WIDTH{1'b0}};
            sync_reg2 <= {WIDTH{1'b0}};
        end else begin
            // 正常工作：级联采样
            sync_reg1 <= din;           // 第一级采样源信号
            sync_reg2 <= sync_reg1;     // 第二级采样第一级输出
        end
    end

    // 同步后的输出取第二级寄存器的值
    assign dout = sync_reg2;

endmodule
