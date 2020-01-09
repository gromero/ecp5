`include "uart.v"

module uart_sim;

/*
module toplevel(input ref_clk, input reset,
            output tx_pin, input rx_pin,
            input [1:0] addr,
            input [7:0] data_in,
            output [7:0] data_out,
            input we,
            input clk,
            input cs,
            output ack, // NC
            output [7:0] led,
	    input [2:0] unused);
*/
// 1 + 2 + 8 + 8 + 4  = 23
// 26 - 23 = 3 unused RPi3 pins

// wire reset;
// assign reset = ~reset_n; // button pressed is '0', but reset is '1'

reg master_clock;
reg wb_clock;
always #1 master_clock = !master_clock;
always #3 wb_clock = !master_clock;

reg rst;
wire txd;
output wire rxd;
reg [1:0] data_addr;
reg [7:0] data_in;
wire [7:0] data_out;
reg we;
reg clk;
reg cs;
wire ack_bit;

  initial begin
    $dumpfile("uart_dumpfile.vcd");
    $dumpvars;
    #0 rst = 0;
    #1 data_addr = 0;
    #2 data_in = 65;
    #3 rst = 1;
    #2000 $stop;
  end

uart serial0(
  .clk(master_clock),          // reference clock = 12 MHz
  .reset(rst),          // 1 => reset
  .tx_bit(txd),        // TX UART pin
  .rx_bit(rxd),	  // RX UART pin
  .wb_addr(data_addr),         // data address
  .wb_data_in(data_in),   // data in bus
  .wb_data_out(data_out), // data out bus
  .wb_we(we),             // read/write bit, only write is current supported
  .wb_clk(clk),           // bus clock
  .wb_stb(cs),            // chip select
  .wb_ack(ack_bit));          // ACK, currently not used

/*
assign led[1:0] = addr[1:0];
assign led[2]   = we;
assign led[3]   = clk;
assign led[4]   = cs;
assign led[5]   = tx_bit;
assign led[6]   = rx_bit;
assign led[7]   = ack;
*/
// assign unused = z;

endmodule
