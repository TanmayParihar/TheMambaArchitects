`timescale 1ns / 1ps

module tb_fp16_mac_unit;

    reg clk;
    reg rst_n;
    reg [15:0] a, b, c;
    reg valid_in;
    wire [15:0] result;
    wire valid_out;
    
    fp16_mac_unit dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .c(c),
        .valid_in(valid_in),
        .result(result),
        .valid_out(valid_out)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Expected results
    reg [15:0] expected [0:4];
    integer out_count;

    initial begin
        // init signals
        rst_n = 1'b1;
        valid_in = 1'b0;
        a = 16'h0000; b = 16'h0000; c = 16'h0000;
        out_count = 0;

        // expected outputs (half-precision hex)
        expected[0] = 16'h4700; // 7.0
        expected[1] = 16'h3C00; // 1.0
        expected[2] = 16'h4880; // 9.0
        expected[3] = 16'h4000; // 2.0
        expected[4] = 16'h4900; // 10.0

        // Apply reset (active low) for a couple of clock cycles
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Stimulus (unrolled - no arrays, no loop index)
        // Input 0: 2 * 3 + 1 = 7
        @(posedge clk);
        a = 16'h4000; b = 16'h4200; c = 16'h3C00; // 2, 3, 1
        valid_in = 1'b1;
        @(posedge clk);
        valid_in = 1'b0;

        // Input 1: 1 * 1 + 0 = 1
        @(posedge clk);
        a = 16'h3C00; b = 16'h3C00; c = 16'h0000; // 1, 1, 0
        valid_in = 1'b1;
        @(posedge clk);
        valid_in = 1'b0;

        // Input 2: 4 * 2 + 1 = 9
        @(posedge clk);
        a = 16'h4400; b = 16'h4000; c = 16'h3C00; // 4, 2, 1
        valid_in = 1'b1;
        @(posedge clk);
        valid_in = 1'b0;

        // Input 3: 0.5 * 2 + 1 = 2
        @(posedge clk);
        a = 16'h3800; b = 16'h4000; c = 16'h3C00; // 0.5, 2, 1
        valid_in = 1'b1;
        @(posedge clk);
        valid_in = 1'b0;

        // Input 4: 5 * 2 + 0 = 10
        @(posedge clk);
        a = 16'h4500; b = 16'h4000; c = 16'h0000; // 5, 2, 0
        valid_in = 1'b1;
        @(posedge clk);
        valid_in = 1'b0;

        // Wait for pipeline to flush (adjust as needed to suit DUT latency)
        #300;

        $display("\n=== TEST COMPLETE ===");
        $finish;
    end

    // Output checker
    always @(posedge clk) begin
        if (valid_out) begin
            if (result === expected[out_count])
                $display("Output %0d OK : %h", out_count, result);
            else
                $display("Output %0d FAIL : got %h expected %h",
                          out_count, result, expected[out_count]);
            out_count = out_count + 1;
        end
    end

endmodule
