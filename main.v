`include "fifo.v"

module main (input clk, input reset, output full, output empty, input[7:0] data_in, output[7:0] data_out, input push, input pop, output [7:0] data_out2led, input [3:0] unused);

fifo fifo0(
  .clk(clk),
  .reset(reset),
  .full(full),
  .empty(empty),
  .data_in(data_in),
  .data_out(data_out),
  .push(push),
  .pop(pop));

assign data_out2led = data_out;

/*
always @ (posedge clk) begin
  data_out[7:1] = data_in[7:1];
end
*/

// assign unused = z;

endmodule
