module t_port(input clk, input [3:0] A, output [3:0] B);

reg [3:0] B;

always @ (posedge clk) begin
B = { A[1], A[0], A[3], A[2] };
end

endmodule
