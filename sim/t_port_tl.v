module t_port_sim;

  reg [3:0] in = 3;

  initial begin
    $dumpfile("t_port_dumpfile.vcd");
    $dumpvars;
    #10 in = 4;
    #100 $stop; // stop after 100 cycles
  end

  // Make clock :)
  reg clk = 0;
  always #5 clk = !clk;

  output wire [3:0] out;
  t_port tp0(clk, in, out);

  initial $monitor("out = %h", out);
endmodule
