module raw_serial(input clk, output txd);

reg [9:0] counter = 0;
wire tx_clk;

reg [1:0] state = 0;
reg [7:0] byte = 65; // 'A'
reg [2:0] bitz = 0;
reg txd = 1;

always @ (posedge clk) begin
  // 12 MHz (master clock) / 625 = 19200 bps (tx_clk)
  // adjust counter == 103 to generate 115200 bps
  if (counter == 624) begin
    counter = 0;
    tx_clk = 1;
  end else begin
    counter = counter + 1;
    tx_clk = 0;
  end
end

always @ (posedge clk) begin
  case (state)
    0:
      if (tx_clk == 1) begin
        txd = 0;
        state = 1;
        bitz = 0;
      end

    1:
      if (tx_clk == 1) begin
        if (bitz == 7) begin
          txd = byte[bitz];
          state = 2;
        end else begin
          txd = byte[bitz];
          bitz = bitz + 1;
        end
      end

    2:
      if (tx_clk == 1) begin
        txd = 1;
        state = 0;
      end
  endcase
end

endmodule
