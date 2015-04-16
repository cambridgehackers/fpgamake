
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

interface LedCtl;
   (* always_ready, enable="rx_data_rdy" *)
   method Action rx(Bit#(8) data);
   (* always_enabled, always_ready, prefix="" *)
   method Action btn_clk( (* port="btn_clk_rx" *) Bool val);
   (* always_ready *)
   method Bit#(8) led_o;
endinterface

(* default_clock_osc="clk_rx", default_reset="rst_clk_rx" *)
(* synthesize *)
module mkLedCtl(LedCtl);
   
   Reg#(Bit#(8))       char_data <- mkReg(0);
   Reg#(Bool)               swap <- mkReg(False);

   method Action rx(data);
      if (swap == True)
         char_data <= {data[3:0], data[7:4]};
      else
         char_data <= data;
   endmethod

   method Action btn_clk(val);
      swap <= val;
   endmethod

   method led_o = char_data; 
   
endmodule
      