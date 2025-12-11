module top (
    input  wire clk,            // system clock
    input  wire rst_n,          // active low reset
    input  wire rx,             // from STM32 TX

    output wire [6:0] seg_tens, // left 7-seg (high digit)
    output wire [6:0] seg_ones  // right 7-seg (low digit)
);

    // UART receiver
    wire [7:0] rx_byte;
    wire       rx_done;

    uart_rx #(
        .CLKS_PER_BIT(16)       // set according to your clock (10MHz -> 87)
    ) u_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (rx),
        .rx_byte (rx_byte),
        .rx_done (rx_done)
    );

    // BCD digits for two 7-seg displays
    reg [3:0] bcd_tens;
    reg [3:0] bcd_ones;

    
	
// 暂存第一个数字字符
	reg       have_first;     // 0 = 还没有第一位，1 = 已经收到第一位
	reg [7:0] first_ascii;    // 保存第一位 ASCII

	always @(posedge clk or negedge rst_n) begin
		 if (!rst_n) begin
			  bcd_tens   <= 4'd0;
			  bcd_ones   <= 4'd0;
			  have_first <= 1'b0;
			  first_ascii <= 8'd0;
		 end else begin
			  if (rx_done) begin
					// 只处理 '0'..'9'，其他字节直接无视
					if (rx_byte >= "0" && rx_byte <= "9") begin
						 if (!have_first) begin
							  // 这是这一组里的第一位数字
							  first_ascii <= rx_byte;
							  have_first  <= 1'b1;
						 end else begin
							  // 这是第二位数字，组成一对：first_ascii + rx_byte
							  bcd_tens   <= first_ascii - "0";  // 高位
							  bcd_ones   <= rx_byte     - "0";  // 低位
							  have_first <= 1'b0;               // 准备下一对
						 end
					end
					// 如果不是 '0'..'9' 就完全无视，不改 bcd_tens / bcd_ones
			  end
		 end
	end
    bcd_to_seg u_seg_tens (
        .bcd (bcd_tens),
        .seg (seg_tens)
    );

    bcd_to_seg u_seg_ones (
        .bcd (bcd_ones),
        .seg (seg_ones)
    );

    // 如果你用的是公共阳极数码管，可以在这里做一次取反：
     wire [6:0] seg_tens_n = ~seg_tens;
     wire [6:0] seg_ones_n = ~seg_ones;
    // 然后在 UCF 里约束 seg_tens_n / seg_ones_n 对应引脚。

endmodule
