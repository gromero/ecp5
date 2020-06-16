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
            output probe0, 
            output reg wb_ack);

localparam TX_DATA_ADDR = 2'b00;
localparam RX_DATA_ADDR = 2'b01;
localparam FREQ_DIV_ADDR = 2'b10;

localparam HIGH = 1'b1;
localparam LOW = 1'b0;

/*
 * Default baudrate is 9600 8N1, i.e. master clock (external) is 12 MHz,
 * hence 12000000/78/16 = 9615.385 = 9600 bps, where 78 is the default
 * value set in 'freq_divider' register and 16 is the fixed divider used
 * to make the tx_clock and rx_clock signals (9600). See comment about
 * the derived clocks from master clock.
 */

reg [7:0] freq_divider = 78;
reg [7:0] freq_counter = 0;
reg uart_clock = LOW;

reg [15:0] tx_clock_counter = 16'b0;
reg tx_clock = LOW;

reg tx_fifo_pop;
reg tx_fifo_push;
reg [7:0] tx_fifo_data_in;
wire [7:0] tx_fifo_data_out;

reg [7:0] rx_buffer = 8'H41;

// reg [10:0] rx_clock_counter = 0;
// reg [10:0] rx_uart_clock_counter = 0;
// reg [10:0] rx_uart_clock_counter_tmp = 0;
// reg rx_clock = LOW;
// reg [10:0] rx_uart_clock = 0;
// reg sync = 0;

reg rx_fifo_pop = LOW;
reg rx_fifo_push = LOW;
reg [7:0] rx_fifo_data_in;
wire [7:0] rx_fifo_data_out;
reg rx_sync = 1'b0;
reg rx_clock;

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
    wb_ack <= LOW;
    wb_state <= IDLE;
    tx_fifo_push <= 0;
    rx_fifo_pop <= 0;
  end
  else if (rx_fifo_pop == HIGH) begin
    rx_fifo_pop <= LOW;
  end else begin

  case (wb_state)
    IDLE:
      if (wb_stb == HIGH) begin
        if (wb_clk == HIGH) begin
          if (wb_we == LOW) begin // write to UART
            case (wb_addr)
              TX_DATA_ADDR: begin
                              tx_fifo_push <= HIGH;
                              tx_fifo_data_in <= wb_data_in;
                            end
              FREQ_DIV_ADDR: freq_divider <= wb_data_in;
            endcase
            wb_ack <= HIGH;
            wb_state <= WRITE_ACK;
          end else begin         // read from UART
            case (wb_addr)
              RX_DATA_ADDR: begin
                              rx_fifo_pop <= HIGH;
                              // wb_data_out <= rx_buffer; // Works OK!
                            end
            endcase
            wb_ack <= HIGH;
            wb_state <= READ_ACK;
          end
        end // wb_clk
      end // wb_stb

    /* write ack */
    WRITE_ACK:
      begin
        tx_fifo_push <= LOW;
        if (wb_clk == LOW) begin
          wb_state <= IDLE;
          wb_ack <= LOW;
        end
      end

    /* read ack */
    READ_ACK:
      begin
        wb_data_out <= rx_fifo_data_out; 
        if (wb_clk == LOW) begin
          wb_state <= IDLE;
          wb_ack <= LOW;
        end
      end // read ack
  endcase
 end
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

// TODO: use tx_bit_counter above instead
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
    tx_bit <= HIGH; // tx idle bit
    tx_fifo_pop <= LOW;
    tx_state <= IDLE;
  end else begin
    case (tx_state)
      0:
         begin
           if (tx_clock == HIGH && tx_fifo_empty == LOW) begin
             tx_bit <= LOW;  // tx start bit
             bitz <= 0;
	     tx_fifo_pop <= HIGH;
             tx_state <= 1;
           end else if (tx_clock == HIGH) begin
             tx_bit <= HIGH; // tx idle bit
           end
         end

      1:
         if (tx_fifo_pop == HIGH) begin
           tx_fifo_pop <= LOW;
	 end else if (tx_clock == HIGH && bitz == 7) begin
           tx_bit <= tx_fifo_data_out[bitz];
           tx_state <= 2;
         end else if(tx_clock == HIGH) begin
           tx_bit <= tx_fifo_data_out[bitz];
           bitz <= bitz + 1;
         end

      2:
         if (tx_clock == HIGH) begin
           tx_bit <= HIGH; // tx stop bit
           tx_state <= 0;
         end
    endcase
  end
end

/******************
 *  UART RX part  *
 ******************/

// FSM states:
localparam IDLE_RX   = 4'b0000;
localparam START_BIT = 4'b0001;
localparam RECV      = 4'b0010;
localparam STOP_BIT  = 4'b0011;
localparam END       = 4'b0100;

reg [15:0] rx_clock_counter = 16'b0;
reg [3:0] rx_state = IDLE_RX;
reg rx_uart_clock;
reg [7:0] rx_bit_ctr = 8'b0;

wire rx_fifo_empty;
wire rx_fifo_full; // NC

/*************
 *  RX FIFO  *
 *************/

fifo rx_fifo0(
  .clk(clk),
  .reset(reset),
  .push(rx_fifo_push),
  .pop(rx_fifo_pop),
  .data_in(rx_fifo_data_in),
  .data_out(rx_fifo_data_out),
  .full(rx_fifo_full),
  .empty(rx_fifo_empty)); // XXX: 'empty' flag is not connected

always @ (posedge clk) begin
    case (rx_state)
      IDLE_RX:
      begin
        if (rx_fifo_push == HIGH) begin
          rx_fifo_push <= LOW;
        end

        if (!rx_bit && rx_clock) begin
          rx_bit_ctr <= 1'b0;
          rx_state <= START_BIT;
        end
      end

      START_BIT:
      begin
        if (rx_clock) begin
          if (rx_bit_ctr == (8 - 1)) begin
//          o_clk <= rx_bit;
            probe0 <= rx_bit; // OK!
            rx_fifo_data_in[rx_bit_ctr] <= rx_bit;
            rx_buffer[rx_bit_ctr] <= rx_bit;
//          rx_fifo_data_in <= 8'H41;
            rx_fifo_push <= HIGH;
            rx_state <= STOP_BIT;
          end else begin
//          o_clk <= rx_bit; 
            probe0 <= rx_bit;  // OK!
            rx_fifo_data_in[rx_bit_ctr] <= rx_bit;
            rx_buffer[rx_bit_ctr] <= rx_bit;
//          rx_fifo_data_in <= 8'H41;
            rx_bit_ctr <= rx_bit_ctr + 1'b1;
          end
        end
     end

     STOP_BIT:
     begin
//       rx_fifo_push <= LOW;
       if (rx_clock) begin
//       o_clk <= LOW;
         probe0 <= LOW; // OK!
         rx_state <= IDLE_RX;
       end
     end

    endcase
end

// assign probe0 = rx_clock;

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
    freq_counter <= 0;
  end
  else begin
    if (freq_counter == freq_divider) begin
      uart_clock <= HIGH;
      freq_counter <= 0;
    end
    else begin
      uart_clock <= LOW;
      freq_counter <= freq_counter + 1;
    end
  end
end

// "tx_clock" : 9600 OK
always @ (posedge clk) begin
  if (tx_clock_counter == (1250 - 1)) begin
    tx_clock <= 1;
    tx_clock_counter <= 0;
  end else begin
    tx_clock <= 0;
    tx_clock_counter <= tx_clock_counter + 1'b1;
  end
end

// "rx_clock" : 9600 OK
always @ (posedge clk) begin
  if (rx_clock_counter == (1250 - 1)) begin
    rx_clock <= 1;
    rx_clock_counter <= 0;
  end
  else begin
    rx_clock <= 0;
    rx_clock_counter <= rx_clock_counter + 1'b1;
  end
 end

endmodule
