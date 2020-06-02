`include "uart.v"
// `timescale 1ns/1ns

module uart_sim_tl;

reg master_clock = 0;
reg wb_clock = 0;
always #1 master_clock = !master_clock;
// always #4 wb_clock = !wb_clock;
// always #50 master_clock = !master_clock;

reg rst;
wire txd;
// output wire rxd;
reg [1:0] data_addr;
reg [7:0] data_in;
wire [7:0] data_out;
reg we;
reg cs;
wire ack_bit;
reg rxd = 1;

  initial begin
    $dumpfile("uart_dumpfile.vcd");
    $dumpvars(0, uart_sim_tl, serial0, serial0.tx_fifo0);

    // Send 0x47 'G' 0b0100_0111
    #1000 rxd = 0;            // start bit
    #(2*1248) rxd = 1;
    #(2*1248) rxd = 0;
    #(2*1248) rxd = 1;
    #(2*1248) rxd = 0;
    #(2*1248) rxd = 1;
    #(2*1248) rxd = 0;
    #(2*1248) rxd = 1;
    #(2*1248) rxd = 0;
    #(2*1248) rxd = 1; // stop bit

    #3000 data_addr = 1; // RX_ADDR
    #100 we = 1;         // READ
    #100 cs = 1;         // CS
    #100 wb_clock = 1;   // 1 cycle to wishbone bus
    #100 wb_clock = 0;

/*
    #10 data_addr = 0;
    #10 data_in = 68; // 'B'
    #0 rst = 1;
    #2 rst = 0; // off reset
    #2 we = 0;
    #2 cs = 1;
    #2 wb_clock = 1;
    #2 wb_clock = 0;
    #2 cs = 0; // de select IC

    // Send 0x47 'G' 0b0100_0111
    #22530 rxd = 0; // start bit
    #25060 rxd = 1;
    #27590 rxd = 1;
    #30120 rxd = 1;
    #32650 rxd = 0;
    #35180 rxd = 0;
    #37710 rxd = 0;
    #40240 rxd = 1;
    #42770 rxd = 0;
    #45300 rxd = 1; // stop bit
*/
    #50000 $stop;
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
