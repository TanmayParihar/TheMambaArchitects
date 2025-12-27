`timescale 1ns / 1ps

module fp16_mac_unit (
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [15:0] c,
    input  wire valid_in,
    output wire [15:0] result,
    output wire valid_out
);

    // AXI handshake wires
    wire s_axis_a_tready;
    wire s_axis_b_tready;
    wire m_axis_mult_tvalid;
    wire m_axis_mult_tready;
    wire m_axis_add_tready;
    assign m_axis_mult_tready = 1'b1;  // always ready
    assign m_axis_add_tready  = 1'b1;  // always ready
    
    // Multiplier
    wire [15:0] mult_result;

    floating_point_1 multiplier (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tdata(a),
        .s_axis_a_tvalid(valid_in),
        .s_axis_a_tready(s_axis_a_tready),
        .s_axis_b_tdata(b),
        .s_axis_b_tvalid(valid_in),
        .s_axis_b_tready(s_axis_b_tready),
        .m_axis_result_tdata(mult_result),
        .m_axis_result_tvalid(m_axis_mult_tvalid),
        .m_axis_result_tready(m_axis_mult_tready)
    );

    // Delay C to match multiplier latency
    // Mult latency = 9 delay = 9
    reg [15:0] c_pipe [0:8];
    integer i;

    // Valid pipeline to track when data is valid
    reg [8:0] valid_pipe;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_pipe <= 9'b0;
            for (i = 0; i < 9; i = i + 1)
                c_pipe[i] <= 16'h0000;
        end else begin
            valid_pipe[0] <= valid_in;
            c_pipe[0] <= valid_in ? c : c_pipe[0];  // Hold value when not valid
            
            for (i = 1; i < 9; i = i + 1) begin
                valid_pipe[i] <= valid_pipe[i-1];
                c_pipe[i] <= valid_pipe[i-1] ? c_pipe[i-1] : c_pipe[i];  // Only shift valid data
            end
        end
    end

    wire [15:0] c_aligned = c_pipe[8];
    
    // Adder
    floating_point_0 adder (
        .aclk(clk),
        .aresetn(rst_n),

        .s_axis_a_tdata(mult_result),
        .s_axis_a_tvalid(m_axis_mult_tvalid),

        .s_axis_b_tdata(c_aligned),
        .s_axis_b_tvalid(m_axis_mult_tvalid),

        .s_axis_operation_tdata(8'h00), // ADD
        .s_axis_operation_tvalid(1'b1),

        .m_axis_result_tdata(result),
        .m_axis_result_tvalid(valid_out),
        .m_axis_result_tready(m_axis_add_tready)
    );

endmodule
