`include "fifo.v"

module main (input clk, input reset, output full, output empty, input[7:0] data_in, output[7:0] data_out, input push, input pop, output [7:0] data_out2led, input [3:0] unused);

/*
module fifo(clk, reset, full, empty, data_in, data_out, push, pop);
*/

// RPi3 # of used pins = 1 + 2 + 16 + 2 = 21 -> 26 - 21 = 4 unused
// ECP5 # of used pins = 1 + 8 = 9

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
