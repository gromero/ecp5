module fifo(clk, reset, full, empty, data_in, data_out, push, pop);

localparam DEPTH = 10;

localparam PUSH = 0;
localparam POP  = 1;

localparam HIGH = 1'b1;
localparam LOW = 1'b0;

input clk;
input reset;

output full;
output empty;

input [7:0] data_in;
output reg [7:0] data_out;

input push;
input pop;

reg [7:0] memory [DEPTH-1:0];
integer top = 0;
integer bottom = 0;
reg last_op = POP;

always @ (posedge clk) begin

  if (reset == 1'b1) begin
    data_out = 1'bz;
    top = 0;
    bottom = 0;
  end
  else begin
    if (push == 1'b1) begin
      memory[top] = data_in;
      top = (top + 1) % DEPTH;
    end

    else if (pop == 1'b1) begin
      data_out = memory[bottom];
      bottom = (bottom + 1) % DEPTH;
    end
  end
end

always @ (posedge clk) begin
  if (reset == HIGH) begin
    last_op = POP;
  end
  else begin
    if (push == HIGH)
      last_op = PUSH;
    else if (pop == HIGH)
      last_op = POP;
    else if (push == HIGH && pop == HIGH)
      last_op = POP;
  end
end

always @ (top, bottom, last_op) begin

if (top == bottom && last_op == PUSH)
  full = HIGH;
else
  full = LOW;

if (top == bottom && last_op == POP)
  empty = HIGH;
else
  empty = LOW;
end

endmodule
