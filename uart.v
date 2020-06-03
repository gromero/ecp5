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

/*
 * Default baudrate is 9600 8N1, i.e. master clock (external) is 12 MHz, and
 * freq_divider is the number of clocks per half-baud.
 * Hence 12000000/(625*2) = 9600 bps, where 625 is the default value set in
 * 'freq_divider' register to make the tx_clock and rx_clock signals (9600).
 */

reg [9:0] freq_divider = 625;
reg [9:0] freq_counter = 0;
reg uart_clock = LOW;

reg [9:0] tx_clock_counter = 0;
reg tx_clock = LOW;

reg tx_fifo_pop;
reg tx_fifo_push;
reg [7:0] tx_fifo_data_in;
wire [7:0] tx_fifo_data_out;

reg [9:0] rx_clock_counter = 0;
reg rx_clock = LOW;
reg sync = 0;

reg rx_fifo_pop;
reg rx_fifo_push;
reg [7:0] rx_fifo_data_in;
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
//			       wb_data_out = 65;
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
        wb_data_out = rx_fifo_data_out;
//        wb_data_out = 65;
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

// FSM states: IDLE, START, SEND, STOP
localparam START = 2'b01;
localparam SEND  = 2'b10;
localparam STOP  = 2'b11;
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
  end
  else begin
    case (tx_state)
      IDLE:
         begin
           if (tx_fifo_empty == LOW)
             tx_state <= START;
         end
      SEND:
        begin
          if (tx_fifo_pop == HIGH)
            tx_fifo_pop <= LOW;
        end
    endcase
  end
end

always @ (posedge tx_clock) begin
  case (tx_state)
    START:
    begin
      tx_bit <= LOW;
      bitz <= 0;
      tx_fifo_pop = HIGH;
      tx_state <= SEND;
    end
    SEND:
    begin
      tx_bit = tx_fifo_data_out[bitz];
      if (bitz == 7)
        tx_state = STOP;
      else begin
        bitz = bitz + 1;
      end
    end
    STOP:
    begin
      tx_bit <= HIGH;
      tx_state = IDLE;
    end
  endcase
end


/******************
 *  UART RX part  *
 ******************/

// FSM states: IDLE, START, RECV, STOP
localparam RX_IDLE =  2'b00;
localparam RX_START = 2'b01;
localparam RECV =     2'b10;
localparam RX_STOP =  2'b11;

reg [1:0] rx_state = RX_IDLE;
reg [3:0] rx_bit_counter = 0;

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
  if (reset == HIGH) begin
    rx_fifo_push = LOW;
    rx_state = RX_IDLE;
  end else begin
    case (rx_state)
      RX_IDLE:
        if (rx_bit == LOW) begin
          sync <= HIGH;
          rx_state <= RX_START;
        end
    endcase
  end
end

always @ (posedge rx_clock) begin
  case (rx_state)
    RX_START:
      begin
        rx_bit_counter <= 0;
        rx_state <= RECV;
      end
    RECV:
      begin
        rx_fifo_data_in[rx_bit_counter] = rx_bit;
        if (rx_bit_counter == 7) begin
          rx_fifo_push <= HIGH;
          rx_state <= RX_STOP;
        end
        else
          rx_bit_counter <= rx_bit_counter + 1;
      end
    RX_STOP:
      begin
        rx_fifo_push <= LOW;
        tx_state <= RX_IDLE;
      end
  endcase
end

/**********************
 *  CLOCK GENERATORS  *
 **********************/

// tx_clock
always @ (posedge clk, reset) begin
	if (reset == HIGH)
		tx_clock_counter <= 0;
	else if (tx_clock_counter == freq_divider -1) begin
		tx_clock_counter <= 0;
		tx_clock <= ~tx_clock;
	end else
		tx_clock_counter <= tx_clock_counter + 1;
end

// rx_clock
always @ (posedge clk, reset, sync) begin
	if (reset == HIGH || sync == HIGH) begin
		rx_clock <= LOW;
		rx_clock_counter <= 0;
		sync <= LOW;
	end else if (rx_clock_counter == freq_divider -1) begin
		rx_clock <= ~rx_clock;
		rx_clock_counter <= 0;
	end else
		rx_clock_counter <= rx_clock_counter + 1;
end

endmodule
