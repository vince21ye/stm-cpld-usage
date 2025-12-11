module uart_rx #(
    parameter integer CLKS_PER_BIT = 16  // 10MHz / 115200 ~= 87
)(
    input  wire clk,
    input  wire rst_n,
    input  wire rx,          // serial input from STM32 TX
    output reg  [7:0] rx_byte,
    output reg        rx_done
);

    // state encoding
    localparam [1:0]
        S_IDLE  = 2'd0,
        S_START = 2'd1,
        S_DATA  = 2'd2,
        S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [2:0]  bit_index;    // 0..7
    reg [6:0]  clk_cnt;      // enough for <=128 cycles/bit

    reg rx_sync1, rx_sync2;
    wire rx_s;

    // 2-flop synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    assign rx_s = rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            rx_byte   <= 8'd0;
            rx_done   <= 1'b0;
            bit_index <= 3'd0;
            clk_cnt   <= 7'd0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_cnt   <= 7'd0;
                    bit_index <= 3'd0;
                    if (rx_s == 1'b0) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    if (clk_cnt == (CLKS_PER_BIT/2 - 1)) begin
                        clk_cnt <= 7'd0;
                        if (rx_s == 1'b0) begin
                            state <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 7'd0;
                        rx_byte[bit_index] <= rx_s;
                        if (bit_index == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 7'd0;
                        rx_done <= 1'b1;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
