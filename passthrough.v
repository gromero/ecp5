module passthrough (input clk, input[17:0] notused, input[7:0] data_in, output[7:0] data_out);

always @ (posedge clk) begin
  data_out[7:1] = data_in[7:1];
end

assign data_out[0] = data_in[0] | notused[0]  |
	                          notused[1]  |
	                          notused[2]  |
	                          notused[3]  |
	                          notused[4]  |
	                          notused[5]  |
	                          notused[6]  |
	                          notused[7]  |
	                          notused[8]  |
	                          notused[9]  |
	                          notused[10] |
	                          notused[11] |
	                          notused[12] |
	                          notused[13] |
	                          notused[14] |
	                          notused[15] |
	                          notused[16] |
	                          notused[17];

endmodule
