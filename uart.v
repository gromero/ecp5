/****
 * wb_addr:
 * 0x00     TX
 * 0x01     RX
 * 0x02     Frequency divider
 */

module uart(input clk, input reset,
            output tx_bit, input rx_bit,
            input [11:0] wb_addr,
            input [7:0] wb_data_in,
            output [7:0] wb_data_out,
            input wb_we,
            input wb_clk,
            input wb_stb,
            output wb_ack);

localparam TX_DATA_ADDR = 12'b00;
localparam RX_DATA_ADDR = 12'b01;
localparam FREQ_DIV_ADDR = 12'b10; 

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

// FSM: idle, read_ack, write_ack
localparam IDLE = 2'b00;
localparam READ_ACK = 2'b01;
localparam WRITE_ACK = 2'b10;
reg [1:0] wb_state = IDLE;

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

// clk----[clk/freq_divisor]---->uart_clock
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

// uart_clock----[uart_clock/16]---->tx_clock
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
