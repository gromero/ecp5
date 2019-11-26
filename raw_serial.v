module raw_serial(input clk, output txd);

reg [7:0] counter;
wire tx_clk;

reg [1:0] state = 0;
reg [7:0] byte = 65; // 'A'
reg [2:0] bit = 0;

always @ (posedge clk) begin
  if (counter == 255) begin
    counter = 0;
    tx_clk = 1;
  end else begin
    counter = counter + 1;
    tx_clk = 0;
  end
end

always @ (posedge tx_clk) begin
  case (state)
    0:
       begin
         txd = 1; 
         state = 1;
       end  

    1:
       if (bit < 8) begin
         txd = byte[bit];
         bit = bit + 1;
       end else begin
         bit = 0;
         state = 2;
       end

    2: if (bit < 2) begin
         txd = 0;
         bit = bit + 1;
       end else begin
         bit = 0;
         state = 0;
       end
  endcase
end

endmodule
