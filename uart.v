`include "fifo.v"

/****************************************
 * wb_addr:
 * 0x00     TX
 * 0x01     RX
 * 0x02     Frequency divider
 ****************************************/

module uart(input clk, input reset,
            output reg tx_bit, input rx_bit,
            input [1:0] wb_addr,
            input [7:0] wb_data_in,
            output reg [7:0] wb_data_out,
            input wb_we,
            input wb_clk,
            input wb_stb,
            output reg wb_ack);

localparam TX_DATA_ADDR = 2'b00;
localparam RX_DATA_ADDR = 2'b01;
localparam FREQ_DIV_ADDR = 2'b10;

localparam HIGH = 1'b1;
localparam LOW = 1'b0;

/* ref_clk is 12 MHz, so Tref_clk = 0.00000008333333s
 * On the other hand, baud rate is 115200, so it's
 * necessary a 115200 * 16 baud rate, so
 * Tbaud_rate = 0.0000005425347, then Tref_clk/Tbaud_rate = 6.510417,
 * and so ~6, hence freq_divider for a 12 MHz is 6.
 * Or simply 12 MHz / (115200 * 16) ~= 6 = freq_divider.
 */
reg [7:0] freq_divider = 6;
reg [7:0] freq_counter = 0;
reg uart_clock = LOW;

reg [7:0] tx_clock_counter = 0;
reg tx_clock = LOW;

reg tx_fifo_pop;
reg tx_fifo_push;
reg [7:0] tx_fifo_data_in;
wire [7:0] tx_fifo_data_out;

reg rx_fifo_pop;
wire rx_fifo_push;
wire [7:0] rx_fifo_data_in;
wire [7:0] rx_fifo_data_out;

// FSM states: idle, read_ack, write_ack
localparam IDLE = 2'b00;
localparam READ_ACK = 2'b01;
localparam WRITE_ACK = 2'b10;
reg [1:0] wb_state = IDLE;

/************************
 *  Wishbone Interface  *
 ************************/

always @ (posedge wb_clk) begin
  if (reset == 1'b1) begin
    wb_ack = 0;
    wb_state = IDLE;
    tx_fifo_push = 0;
    rx_fifo_pop = 0;
  end
  else
    if (wb_state == IDLE) begin
      if (wb_stb == HIGH) begin
        /* write to UART: wb_we == LOW */
        if (wb_we == LOW) begin
          case (wb_addr)
  	    TX_DATA_ADDR : begin
                             tx_fifo_data_in = wb_data_in;
                             tx_fifo_push = HIGH;
                           end
            FREQ_DIV_ADDR: freq_divider = wb_data_in; 
  	  endcase
          wb_state = WRITE_ACK;
          wb_ack = HIGH;
        end
        /* read from UART: wb_we == HIGH */
        else begin 
          case (wb_addr)
            RX_DATA_ADDR: begin
                            wb_data_out = rx_fifo_data_out;
                            rx_fifo_pop = HIGH;
                          end
          endcase
          wb_state = READ_ACK;
          wb_ack = HIGH;
        end
      end
    end
    /* write ack */
    else if (wb_state == WRITE_ACK) begin
      tx_fifo_push = LOW;
      if (wb_stb == LOW) begin
        wb_state = IDLE;
        wb_ack = LOW;
      end
    end
    /* read ack */
    else if (wb_state == READ_ACK) begin
      rx_fifo_pop = LOW;
      if (wb_stb == LOW) begin
        wb_state = IDLE;
        wb_ack = LOW;
      end
    end // read ack
end

/******************
 *  UART TX part  *
 ******************/

// FSM states: IDLE, SEND, STOP
localparam SEND = 2'b01;
localparam STOP = 2'b10;
reg [1:0] tx_state = IDLE;
reg [2:0] tx_bit_counter = 0;

wire tx_fifo_empty;
wire tx_fifo_full; // NC

/*************
 *  TX FIFO  *
 *************/

reg [7:0] byte = 65; // 'A'
reg [2:0] bitz = 0;

fifo tx_fifo0(
  .clk(clk),
  .reset(reset),
  .push(tx_fifo_push),
  .pop(tx_fifo_pop),
  .data_in(tx_fifo_data_in),
  .data_out(tx_fifo_data_out),
  .full(tx_fifo_full), // XXX: 'full' flag is not connected
  .empty(tx_fifo_empty));

always @ (posedge clk) begin
/*
  if (reset == 1'b1) begin
    tx_bit = 1'b1; // tx idle bit
    tx_fifo_pop = 1'b0;
    tx_state = IDLE;
  end
*/
/*
else begin
    case (tx_state)

      IDLE:
 //   if (tx_clock == 1'b1 && tx_fifo_empty != 1'b1) begin
      if (tx_clock == 1'b1) begin
        tx_bit = 1'b0;   // tx start bit
        tx_fifo_pop = 1'b1; // pop byte
        tx_state = SEND;
      end else begin
        tx_bit = 1'b1;   // tx idle bit
        tx_fifo_pop = 1'b0; // don't pop
      end

      SEND:
      if (tx_clock == 1'b1 && tx_bit_counter <= 7) begin
        tx_bit = !tx_bit;// tx_fifo_data_out[tx_bit_counter]; // tx data bit
        tx_bit_counter = tx_bit_counter + 1;
      end else begin
        tx_bit_counter = 0;
        tx_state = STOP;
      end

      STOP:
      if (tx_clock == 1'b1) begin
        tx_bit = 1'b1; // tx stop bit
        tx_state = IDLE;
      end
    endcase
  end
*/
  if (reset == HIGH) begin
    tx_bit = HIGH; // tx idle bit
    tx_fifo_pop = LOW;
    tx_state = 0; // IDLE
  end

  case (tx_state)
    0:
       begin
	 if (tx_clock == HIGH && tx_fifo_empty == LOW) begin
           tx_bit = 0; // tx start bit
           tx_state = 1;
           bitz = 0;
   	   tx_fifo_pop = HIGH;
//         byte = tx_fifo_data_out;
	 end else begin
           tx_bit = 1; // tx idle bit
           tx_fifo_pop = LOW;
         end
       end

    1:
       if (bitz == 7) begin
//       tx_fifo_pop = HIGH;
//	 tx_bit = tx_fifo_data_out[bitz];
         tx_bit = byte[bitz];
         tx_state = 2;
       end else begin
//       tx_fifo_pop = HIGH;
//       tx_bit = tx_fifo_data_out[bitz];
         tx_bit = byte[bitz];
         bitz = bitz + 1;
       end

    2: 
       begin
         tx_bit = 1; // tx stop bit
         tx_state = 0;
       end
  endcase
end

/**********************
 *  CLOCK GENERATORS  *
 **********************/

// clk---->[clk/freq_divisor]---->uart_clock
//
// N.B.: freq_divisor should account for making uart_clock 16x faster than baud
// rate, so uart_clock / 16 can give the correct tx and rx freq. This is
// specially useful on RX code because we use a 8 uart_clock delay to sample
// right in the middle of receiving signal.
always @ (posedge clk) begin
  if (reset == HIGH) begin
    freq_counter = 0;
  end
  else begin
    if (freq_counter == freq_divider) begin
      uart_clock = HIGH;
      freq_counter = 0;
    end
    else begin
      uart_clock = LOW;
      freq_counter = freq_counter + 1;
    end
  end
end

// uart_clock---->[uart_clock/16]---->tx_clock
always @ (posedge clk) begin
  if (reset == HIGH) begin
    tx_clock_counter = 0;
  end
  else if (uart_clock == HIGH) begin
    tx_clock_counter = tx_clock_counter + 1;
    if (tx_clock_counter == 15) begin
       tx_clock_counter = 0;
       tx_clock = HIGH;
    end
    else begin
      tx_clock = LOW;
    end
  end
  else begin // uart_clock == LOW
    tx_clock = LOW;
  end
end

endmodule
