`include "uart.v"

module uart_sim_tl;

reg master_clock = 0;
reg wb_clock = 0;
always #1 master_clock = !master_clock;
// always #4 wb_clock = !wb_clock;

reg rst;
wire txd;
output wire rxd;
reg [1:0] data_addr;
reg [7:0] data_in;
wire [7:0] data_out;
reg we;
reg cs;
wire ack_bit;

  initial begin
    $dumpfile("uart_dumpfile.vcd");
    $dumpvars(0, uart_sim_tl, serial0, serial0.tx_fifo0);
    #10 data_addr = 0;
    #10 data_in = 65;
    #0 rst = 1;
    #2 rst = 0; // off reset
    #2 we = 0;
    #2 cs = 1;
    #2 wb_clock = 1;
    #2 wb_clock = 0;
    #2 cs = 0; // de select IC
    #1000 $stop;
  end

uart serial0(
  .clk(master_clock),     // reference clock = 12 MHz
  .reset(rst),            // 1 => reset
  .tx_bit(txd),           // TX UART pin
  .rx_bit(rxd),	          // RX UART pin
  .wb_addr(data_addr),    // data address
  .wb_data_in(data_in),   // data in bus
  .wb_data_out(data_out), // data out bus
  .wb_we(we),             // read/write bit, only write is current supported
  .wb_clk(wb_clock),      // bus clock
  .wb_stb(cs),            // chip select
  .wb_ack(ack_bit));      // ACK, currently not used

endmodule
