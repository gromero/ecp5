module fifo(clk, reset, full, empty, data_in, data_out, push, pop);

localparam DEPTH = 2;

localparam PUSH = 0;
localparam POP  = 1;

localparam HIGH = 1'b1;
localparam LOW = 1'b0;

input clk;
input reset;

output wire full;
output wire empty;

input [7:0] data_in;
output reg [7:0] data_out;

input push;
input pop;

reg [7:0] memory [DEPTH-1:0];
integer top = 0;
integer bottom = 0;
reg last_op = POP;

always @ (posedge reset) begin
    data_out <= 1'bz;
    top <= 0;
    bottom <= 0;
end

always @ (posedge push) begin
      memory[top] = data_in;
      top = (top + 1) % DEPTH;
end

always @ (posedge pop) begin
      data_out = memory[bottom];
      bottom = (bottom + 1) % DEPTH;
end

assign full = ((top+1)%DEPTH == bottom);
assign empty = (top == bottom);

endmodule
