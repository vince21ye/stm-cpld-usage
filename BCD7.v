`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: BCD7
// Purpose: BCD (0-9) to 7-segment for common-anode (active-LOW)
// Ports:  bcd[3:0] -> digit; a..g -> segments (0=ON, 1=OFF)
//////////////////////////////////////////////////////////////////////////////////
module BCD7(
    input  wire [3:0] bcd,
    output wire a,
    output wire b,
    output wire c,
    output wire d,
    output wire e,
    output wire f,
    output wire g
);

    // seg_n = {a,b,c,d,e,f,g}, active-LOW for common-anode
    reg [6:0] seg_n;

    always @* begin
        case (bcd)
            4'd0: seg_n = 7'b0000001;
            4'd1: seg_n = 7'b1001111;
            4'd2: seg_n = 7'b0010010;
            4'd3: seg_n = 7'b0000110;
            4'd4: seg_n = 7'b1001100;
            4'd5: seg_n = 7'b0100100;
            4'd6: seg_n = 7'b0100000;
            4'd7: seg_n = 7'b0001111;
            4'd8: seg_n = 7'b0000000;
            4'd9: seg_n = 7'b0000100;
            default: seg_n = 7'b1111111; // blank for non-BCD
        endcase
    end

    // Map bus to individual segment outputs
    assign {a,b,c,d,e,f,g} = seg_n;

endmodule
