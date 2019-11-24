`include "fifo.v"

/****************************************
 * wb_addr:
 * 0x00     TX
 * 0x01     RX
 * 0x02     Frequency divider
 ****************************************/

module uart(input clk, input reset,
            output tx_bit, input rx_bit,
            input [1:0] wb_addr,
            input [7:0] wb_data_in,
            output [7:0] wb_data_out,
            input wb_we,
            input wb_clk,
            input wb_stb,
            output wb_ack);

localparam TX_DATA_ADDR = 2'b00;
localparam RX_DATA_ADDR = 2'b01;
localparam FREQ_DIV_ADDR = 2'b10;

localparam HIGH = 1'b1;
localparam LOW = 1'b0;
reg [7:0] freq_divider;
reg [7:0] freq_counter = 0;
reg uart_clock = LOW;

reg [7:0] tx_clock_counter = 0;
reg tx_clock = LOW;

reg push_data;
reg pop_data;

wire [7:0] tx_fifo_data_in;
wire [7:0] tx_fifo_data_out;

wire [7:0] rx_fifo_data_in;
wire [7:0] rX_fifo_data_out;

// FSM states: idle, read_ack, write_ack
localparam IDLE = 2'b00;
localparam READ_ACK = 2'b01;
localparam WRITE_ACK = 2'b10;
reg [1:0] wb_state = IDLE;

/*********************
  wishbone interface
**********************/

always @ (posedge wb_clk) begin
  if (reset == 1'b1) begin
    wb_ack = 0;
    wb_state = IDLE;
    push_data = 0;
    pop_data = 0;
  end
  else
    if (wb_state == IDLE) begin
      if (wb_stb == HIGH) begin
        /* write to UART: wb_we == LOW */
        if (wb_we == LOW) begin
          case (wb_addr)
  	    TX_DATA_ADDR : begin
                             tx_fifo_data_in = wb_data_in;
                             push_data = HIGH;
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
                            pop_data = HIGH;
                          end
          endcase
          wb_state = READ_ACK;
          wb_ack = HIGH;
        end
      end
    /* write ack */
    else if (wb_state == WRITE_ACK) begin
      push_data = LOW;
      if (wb_stb == LOW) begin
        wb_state = IDLE;
        wb_ack = LOW;
      end
    end
    /* read ack */
    else if (wb_state == READ_ACK) begin
      pop_data = LOW;
      if (wb_stb == LOW) begin
        wb_state = IDLE;
        wb_ack = LOW;
      end
    end // read ack
  end // wb_state
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

/*************
 *  TX FIFO  *
 *************/

fifo tx_fifo0(
  .clk(clk),
  .reset(reset),
  .push(push_data),
  .pop(pop_data),
  .data_in(tx_fifo_data_in),
  .data_out(tx_fifo_data_out),
  .full(wb_ack), // XXX: current 'full' line from FIFO is wrongly routed to wb_ack just to attached to some pin
  .empty(tx_fifo_empty));

always @ (posedge clk) begin
  if (reset == 1'b1) begin
    tx_bit = 1'b1; // tx idle bit
    pop_data = 0'b0;
    tx_state = IDLE;
  end else begin
    case (tx_state)
      IDLE:
      if (tx_clock == 1'b01 && tx_fifo_empty != 1'b01) begin
        tx_bit = 1'b0;   // tx start bit
        pop_data = 1'b1; // pop byte
        tx_state = SEND;
      end else begin
        tx_bit = 1'b1;   // tx idle bit
        pop_data = 1'b0; // don't pop
      end

      SEND:
      if (tx_clock == 1'b01 && tx_bit_counter <= 7) begin
        tx_bit = tx_fifo_data_out[tx_bit_counter]; // tx data bit
        tx_bit_counter = tx_bit_counter + 1;
      end else begin
        tx_bit_counter = 0;
        tx_state = STOP;
      end

      STOP:
      if (tx_clock == 1'b01) begin
        tx_bit = 1'b1; // tx stop bit
        tx_state = IDLE;
      end
    endcase
  end
end

/**********************
 *  CLOCK GENERATORS  *
 **********************/

// clk---->[clk/freq_divisor]---->uart_clock
//
// N.B.: freq_divisor should account for making uart_clock 16x faster than baud
// rate, so uart_clock / 16 can give the correct tx and rx freq. This is
// specially usuful on rx code because we use 8 uart_clock cycles to sample
// right "in the middle" of tx_clock by delaying 8 cycles.
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