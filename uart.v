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

always @ (posedge clk) begin
  if (reset == 1'b1) begin
    wb_ack = LOW;
    wb_state = IDLE;
    tx_fifo_push = 0;
    rx_fifo_pop = 0;
  end
  else
  case (wb_state)
    IDLE:
      if (wb_stb == HIGH) begin
        if (wb_clk == HIGH) begin
          if (wb_we == LOW) begin // write to UART
            case (wb_addr)
              TX_DATA_ADDR: begin
                              tx_fifo_push = HIGH;
                              tx_fifo_data_in = wb_data_in;
                            end
              FREQ_DIV_ADDR: freq_divider = wb_data_in;
            endcase
            wb_ack = HIGH;
            wb_state = WRITE_ACK;
          end else begin         // read from UART
            case (wb_addr)
              RX_DATA_ADDR: begin
                              rx_fifo_pop = HIGH;
                              wb_data_out = rx_fifo_data_out;
                            end
            endcase
            wb_ack = HIGH;
            wb_state = READ_ACK;
          end
        end // wb_clk
      end // wb_stb

    /* write ack */
    WRITE_ACK:
      begin
        tx_fifo_push = LOW;
        if (wb_clk == LOW) begin
          wb_state = IDLE;
          wb_ack = LOW;
        end
      end

    /* read ack */
    READ_ACK:
      begin
        rx_fifo_pop = LOW;
        if (wb_clk == LOW) begin
          wb_state = IDLE;
          wb_ack = LOW;
        end
      end // read ack
  endcase
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
  if (reset == HIGH) begin
    tx_bit = HIGH; // tx idle bit
    tx_fifo_pop = LOW;
    tx_state = IDLE;
  end else begin
    case (tx_state)
      0:
         begin
           if (tx_clock == HIGH && tx_fifo_empty == LOW) begin
             tx_bit = LOW;  // tx start bit
             bitz = 0;
	     tx_fifo_pop = HIGH;
             tx_state = 1;
           end else if (tx_clock == HIGH) begin
             tx_bit = HIGH; // tx idle bit
           end
         end

      1:
         if (tx_fifo_pop == HIGH) begin
           tx_fifo_pop = LOW;
	 end else if (tx_clock == HIGH && bitz == 7) begin
           tx_bit = tx_fifo_data_out[bitz];
           tx_state = 2;
         end else if(tx_clock == HIGH) begin
           tx_bit = tx_fifo_data_out[bitz];
           bitz = bitz + 1;
         end

      2:
         if (tx_clock == HIGH) begin
           tx_bit = HIGH; // tx stop bit
           tx_state = 0;
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

// master_clock-->[master_clock/freq_divider]=uart_clock-->[uart_clock/16]=tx_clock
always @ (posedge clk) begin
  if (reset == HIGH) begin
    tx_clock_counter = 0;
  end
  else if (uart_clock == HIGH) begin
    tx_clock_counter = tx_clock_counter + 1;
    if (tx_clock_counter == 16) begin
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

// master_clock-->[master_clock/freq_divider]=uart_clock-->[uart_clock/16]=rx_clock
always @ (posedge clk) begin
  if (reset == HIGH) begin
    rx_clock_counter = 0;
  end
  else if (uart_clock == HIGH) begin
    rx_clock_counter = rx_clock_counter + 1;
    if (rx_clock_counter == 16) begin
       rx_clock_counter = 0;
       rx_clock = HIGH;
    end
    else begin
      rx_clock = LOW;
    end
  end
  else begin
    rx_clock = LOW;
  end
end

endmodule
