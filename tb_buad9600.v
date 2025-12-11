`timescale 1ns/1ps

module tb_clkdiv_9600;

    // Testbench signals
    reg clk = 0;
    reg rst = 1;
    wire tick;

    // Instantiate the DUT (Device Under Test)
    clkdiv_9600 uut (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    // Generate 50 MHz clock (20 ns period)
    always #10 clk = ~clk;
    // |---10ns---|---10ns---|
    // Rising edge every 20ns ? 50MHz

    initial begin
        $display("Time (ns)   tick");
        $monitor("%8t    %b", $time, tick);
    end

    // Stimulus sequence
    initial begin
        // Apply reset at start
        rst = 1;
        #100;     // wait 100 ns
        rst = 0;  // release reset

        // Let simulation run long enough to see many tick pulses
        #2000000; // run for 2 ms (approx 19 pulses @ 9600 baud)
        $finish;
    end

endmodule
