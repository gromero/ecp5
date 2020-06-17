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
            output reg probe0,
            output reg wb_ack);

localparam TX_DATA_ADDR = 2'b00;
localparam RX_DATA_ADDR = 2'b01;
localparam FREQ_DIV_ADDR = 2'b10;

localparam HIGH = 1'b1;
localparam LOW = 1'b0;

// Default: 12 MHz / 1250 = 9600 8N1
reg [11:0] freq_divider = 1250;
reg [15:0] uart_clock_counter = 16'b0;
reg uart_clock = LOW;

reg tx_fifo_pop = LOW;
reg tx_fifo_push = LOW;
reg [7:0] tx_fifo_data_in;
wire [7:0] tx_fifo_data_out;

reg rx_fifo_pop = LOW;
reg rx_fifo_push = LOW;
reg [7:0] rx_fifo_data_in;
wire [7:0] rx_fifo_data_out;

// FSM states:
localparam IDLE      = 2'b00;
localparam READ_ACK  = 2'b01;
localparam WRITE_ACK = 2'b10;
localparam READ      = 2'b11;
reg [1:0] wb_state = IDLE;

/************************
 *  Wishbone interface  *
 ************************/

always @ (posedge clk) begin
  if (reset) begin
    wb_ack <= LOW;
    wb_state <= IDLE;
    tx_fifo_push <= LOW;
    rx_fifo_pop <= LOW;
  end else begin
    case (wb_state)
      IDLE:
      // check if chip is selected and clock is high
      if (wb_stb && wb_clk) begin
        if (wb_we == LOW) begin // ** WRITE **
          // select register
          case (wb_addr)
            TX_DATA_ADDR:
            begin
              tx_fifo_push <= HIGH;
              tx_fifo_data_in <= wb_data_in;
            end

            FREQ_DIV_ADDR:
            begin
              freq_divider <= wb_data_in;
            end
          endcase

          wb_ack <= HIGH;
          wb_state <= WRITE_ACK;
        end else begin        // ** READ **
          // select register
          case (wb_addr)
            RX_DATA_ADDR:
            begin
              rx_fifo_pop <= HIGH;
            end
          endcase

          wb_ack <= HIGH;
          wb_state <= READ_ACK;
        end
      end // wb_stb && wb_clk

      /* Write ack (0 state) for a write operation */
      WRITE_ACK:
      begin
        tx_fifo_push <= LOW;
        if (wb_clk == LOW) begin
          wb_ack <= LOW;
          wb_state <= IDLE;
        end
      end

      /* Grab data from FIFO and write ack (0 state) for a read operation */
      READ_ACK:
      begin
        // XXX: What wb_data_out gets on the next cycle when
        // rx_fifo_pop became LOW and FIFO is not popping,
        // i.e. before it goes back to IDLE (wb_clk turns LOW)?
        wb_data_out <= rx_fifo_data_out;
        rx_fifo_pop <= LOW;
        if (wb_clk == LOW) begin
          wb_ack <= LOW;
          wb_state <= IDLE;
        end
      end
    endcase
  end
end

/******************
 *  UART TX part  *
 ******************/

// FSM states:
localparam IDLE_TX = 2'b00;
localparam SEND    = 2'b01;
localparam STOP    = 2'b10;
reg [1:0] tx_state = IDLE;

reg [2:0] tx_bit_ctr = 0;

wire tx_fifo_empty;
wire tx_fifo_full; // NC

/*************
 *  TX FIFO  *
 *************/

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
      IDLE_TX:
      begin
        if (uart_clock == HIGH && tx_fifo_empty == LOW) begin
          tx_bit <= LOW;  // tx start bit
          tx_bit_ctr <= 0;
          tx_fifo_pop <= HIGH;
          tx_state <= SEND;
        end else if (uart_clock == HIGH) begin
          tx_bit <= HIGH; // tx idle bit
        end
      end

      SEND:
        if (tx_fifo_pop == HIGH) begin
          tx_fifo_pop <= LOW;
        end else if (uart_clock == HIGH && tx_bit_ctr == (8 - 1)) begin
          tx_bit <= tx_fifo_data_out[tx_bit_ctr];
          tx_state <= STOP;
        end else if(uart_clock == HIGH) begin
          tx_bit <= tx_fifo_data_out[tx_bit_ctr];
          tx_bit_ctr <= tx_bit_ctr + 1;
        end

      STOP:
        if (uart_clock == HIGH) begin
          tx_bit <= HIGH; // tx stop bit
          tx_state <= IDLE_TX;
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
reg [3:0] rx_state = IDLE_RX;

reg [7:0] rx_bit_ctr = 8'b0;

wire rx_fifo_empty; // NC
wire rx_fifo_full;  // NC

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
  .full(rx_fifo_full),    // FIXME: 'full' flag is not used!
  .empty(rx_fifo_empty)); // XXX: 'empty' flag is not connected

always @ (posedge clk) begin
    case (rx_state)
      IDLE_RX:
      begin
        if (!rx_bit && uart_clock) begin
          rx_bit_ctr <= 1'b0;
          rx_state <= START_BIT;
        end
      end

      START_BIT:
      begin
        if (uart_clock) begin
          if (rx_bit_ctr == (8 - 1)) begin
//          probe0 <= rx_bit; // OK!
            rx_fifo_data_in[rx_bit_ctr] <= rx_bit;
            // XXX: Why asserting HIGH here doesn't
            // conflict with assignment above?
            rx_fifo_push <= HIGH;
            rx_state <= STOP_BIT;
          end else begin
//          probe0 <= rx_bit; // OK!
            rx_fifo_data_in[rx_bit_ctr] <= rx_bit;
            rx_bit_ctr <= rx_bit_ctr + 1'b1;
          end
        end
     end

     STOP_BIT:
     begin
       rx_fifo_push <= LOW;
       if (uart_clock) begin
//       probe0 <= LOW; // OK!
         rx_state <= IDLE_RX;
       end
     end

    endcase
end

/***********
 *  CLOCK  *
 ***********/

// "uart_clock" : 9600 (default)
always @ (posedge clk) begin
  if (uart_clock_counter == (freq_divider - 1)) begin
    uart_clock <= 1;
    uart_clock_counter <= 0;
  end else begin
    uart_clock <= 0;
    uart_clock_counter <= uart_clock_counter + 1'b1;
  end
end

endmodule
