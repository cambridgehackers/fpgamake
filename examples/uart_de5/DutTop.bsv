// File: $RCSfile: DutTop.bsv,v $ ---  Author: Suhas Pai  --- Created: 2014-01-14 

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// IMPORTS
import Xilinx       :: *;       // needed for instantiating Xilinx cells
import Clocks       :: *;       // needed for synchronizing reset
import DefaultValue :: *;       // needed for default value

// DUT
import UART         :: *;       // needed for uart logic
import LedCtl       :: *;       // control led output
import MetaHarden   :: *;       // synchronizer to harden against metastability

// Interface
interface DutTop;
   (* always_ready *)
   method Bit#(8) led_pins;
endinterface

// Module   
(* clock_prefix = "",  reset_prefix = "" *)
(* no_default_clock, no_default_reset *)
(* synthesize *)
module mkDutTop(Clock clk_pin,     // Clock input (from pin)
                Reset rst_pin,       // Active HIGH reset (from pin)
                (* clocked_by="no_clock", reset_by="no_reset" *)   
                Bool  btn_pin,       // Button to swap high and low bits
                (* clocked_by="no_clock", reset_by="no_reset" *)
                Bit#(1) rxd_pin,     // RS232 RXD pin - directly from pin
                DutTop ifc);

   // Ref: $BLUESPECDIR/BSVSource/Xilinx/XilinxCells.bsv
   Clock            clk_i  = clk_pin;
   Clock            clk_rx = clk_i;
   Reset            rst_i  = rst_pin;
   
   Wire#(Bit#(1))   rxd_i  <- mkReg(defaultValue, clocked_by clk_i, reset_by rst_i);
   rule rxd_i_write;
      rxd_i <= rxd_pin;
   endrule
   // Reference: $BLUESPECDIR/Verilog/SyncBit.v
   SyncBitIfc#(Bit#(1))      rxd_clk_rx <- mkSyncBit(clk_i, rst_i, clk_rx);
   rule rxd_rx_clk_write;
      rxd_clk_rx.send(rxd_i);
   endrule

   // Ref: $BLUESPECDIR/Verilog/SyncResetA.v
   Reset            rst_clk_rx  <-  mkAsyncReset(2, rst_i, clk_rx);
   
   // And the button input
   Wire#(Bool)      btn_i  <- mkReg(defaultValue, clocked_by clk_i, reset_by rst_i);   
   rule btn_i_write;
      btn_i <= btn_pin;
   endrule
   // Reference: $BLUESPECDIR/Verilog/SyncBit.v
   SyncBitIfc#(Bool)      btn_clk_rx <- mkSyncBit(clk_i, rst_i, clk_rx);
   rule btn_clk_rx_write;
      btn_clk_rx.send(btn_i);
   endrule
   
   // Instantiate UART receiver (rx) module
   UartRx uart_rx <- mkUartRx(clocked_by clk_rx, reset_by rst_clk_rx);
   rule uart_rx_rxd_enable;
      uart_rx.rxd_clk(rxd_clk_rx.read());
   endrule
   rule frame_error;
      if (uart_rx.frm_err() == True)
         begin
            $display("Error: frm_err - The STOP bit was not detected");
            $finish(1);
         end
   endrule
   
   // Instantiate Led Control
   LedCtl led_ctl <- mkLedCtl(clocked_by clk_rx, reset_by rst_clk_rx);
   rule update_btn;
      led_ctl.btn_clk(btn_clk_rx.read());
   endrule
   rule update_char;
      led_ctl.rx(uart_rx.rx_data());
   endrule
   
   // Interface
   Wire#(Bit#(8))   led_dut_out  <- mkReg(defaultValue, clocked_by clk_rx, reset_by noReset);
   rule led_write;
      led_dut_out <= led_ctl.led_o();
   endrule

   method led_pins = led_dut_out;
   
endmodule
