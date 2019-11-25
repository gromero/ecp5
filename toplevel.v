`include "uart.v"

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
	    input [3:0] unused);

// 2 + 8 + 8 + 3  = 18 + 3 = 21
// 26 - 26 = 4 unused RPi3 pins

// wire reset;
// assign reset = ~reset_n; // button pressed is '0', but reset is '1'

uart serial0(
  .clk(ref_clk),          // reference clock = 12 MHz
  .reset(reset),          // 1 => reset
  .tx_bit(tx_pin),        // TX UART pin
  .rx_bit(rx_pin),	  // RX UART pin
  .wb_addr(addr),         // data address
  .wb_data_in(data_in),   // data in bus
  .wb_data_out(data_out), // data out bus
  .wb_we(we),             // read/write bit, only write is current supported
  .wb_clk(clk),           // bus clock
  .wb_stb(cs),            // chip select
  .wb_ack(ack));          // ACK, currently not used

assign led[1:0] = addr[1:0];
assign led[2]   = we;
assign led[3]   = clk;
assign led[4]   = cs;
assign led[5]   = tx_bit;
assign led[6]   = rx_bit;
assign led[7]   = ack;

// assign unused = z;

endmodule
