package Xorshift128plus;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

typedef 64 BIT_WIDTH;

interface Xorshift128plusIfc;
	method ActionValue#(Bit#(BIT_WIDTH)) get_val();
endinterface: Xorshift128plusIfc

(* synthesize *)
module mkXorshift128plus(Xorshift128plusIfc);
	Reg#(UInt#(BIT_WIDTH)) reg_state0 <- mkReg(64'd12321332463476978);
	Reg#(UInt#(BIT_WIDTH)) reg_state1 <- mkReg(64'd87684736876123868);
	FIFO#(Bit#(BIT_WIDTH)) fifo_val_out <- mkPipelineFIFO;

	rule update_state;
		let x = reg_state0;
		let y = reg_state1;
		reg_state0 <= y;
		x = x ^ (x << 23);
		let updated_val = x ^ y ^ (x >> 17) ^ (y >> 26);
		reg_state1 <= updated_val;
		fifo_val_out.enq(pack(reg_state1 + updated_val));
		//$display("%b, %b", reg_state0, reg_state1);
	endrule

	method ActionValue#(Bit#(BIT_WIDTH)) get_val();
		let val = fifo_val_out.first;
		fifo_val_out.deq();
		return val;
	endmethod

endmodule: mkXorshift128plus

endpackage: Xorshift128plus 
