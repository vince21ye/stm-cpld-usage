module shift_register_sipo #(
    parameter WIDTH = 8    // 移位寄存器位宽，可调
)(
    input  wire clk,       // 时钟
    input  wire rst,       // 同步复位（高有效）
    input  wire shift_en,  // 移位使能（高有效）
    input  wire serial_in, // 串行输入 bit
    output reg  [WIDTH-1:0] parallel_out // 并行输出寄存器
);

    always @(posedge clk) begin
        if (rst) begin
            parallel_out <= {WIDTH{1'b0}};   // resest
        end 
        else if (shift_en) begin
            // The serial bit enters the most significant bit (MSB), and all other data shift right by one position.
            parallel_out <= {serial_in, parallel_out[WIDTH-1:1]};
        end
    end

endmodule
