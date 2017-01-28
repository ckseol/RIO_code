package BCH_encoder;

import FIFO::*;
import SpecialFIFOs::*;
import BCH_common::*;

interface BCHEncoderIfc;
        method Action load_msg_bits(MESSAGE msg_bits);
        //method ActionValue#(MESSAGE) get_encoded();
	method ActionValue#(ENCODED) get_encoded();
endinterface: BCHEncoderIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkBCHEncoder(BCHEncoderIfc);
	Reg#(ENCODED) reg_state_vector <- mkReg(0); 
	FIFO#(MESSAGE) fifo_msg_in <- mkBypassFIFO;
	FIFO#(ENCODED) fifo_parity <- mkPipelineFIFO;
	//FIFO#(MESSAGE) fifo_encoded_out <- mkPipelineFIFO;
	Reg#(UInt#(MSG_IN_CNT_BIT_WIDTH)) reg_in_cnt <- mkReg(0);
        Reg#(UInt#(MSG_IN_CNT_BIT_WIDTH)) reg_out_cnt <- mkReg(0);

	//(* mutually_exclusive = "encoding, encoded_out" *)
	rule encoding (reg_in_cnt < fromInteger(valueOf(MAX_MSG_IN_CNT_VAL)));
		let current_in = fifo_msg_in.first;
		fifo_msg_in.deq();
		//fifo_encoded_out.enq(current_in);
		reg_state_vector <= encode(reg_state_vector, current_in);
		reg_in_cnt <= reg_in_cnt + 1;
	endrule

	rule encoding_done (reg_in_cnt == fromInteger(valueOf(MAX_MSG_IN_CNT_VAL)));
		fifo_parity.enq(reg_state_vector);
		reg_state_vector <= 0;
		reg_in_cnt <= 0;
	endrule
/*
	rule encoded_out (reg_out_cnt < fromInteger(valueOf(PARITY_CNT)));
		let parity_vec = fifo_parity.first;
		
		let parity_out = case(reg_out_cnt)
				 0: parity_vec[329:298]; 
                                 1: parity_vec[297:266];
                                 2: parity_vec[265:234];
                                 3: parity_vec[233:202];
                                 4: parity_vec[201:170];
                                 5: parity_vec[169:138];
                                 6: parity_vec[137:106];
                                 7: parity_vec[105:74];
                                 8: parity_vec[73:42];
                                 9: parity_vec[41:10];
                                10: {parity_vec[9:0], 22'd0};
				endcase;
		MESSAGE parity_out_reversed;
		for (Integer i=0 ; i<32 ; i=i+1)
			parity_out_reversed[i] = parity_out[31-i];
		fifo_encoded_out.enq(parity_out_reversed);	
		//fifo_encoded_out.enq(parity_out);
		reg_out_cnt <= reg_out_cnt + 1;
	endrule

	rule encoded_out_done (reg_out_cnt == fromInteger(valueOf(PARITY_CNT)));
		fifo_parity.deq();
		reg_out_cnt <= 0;
	endrule
*/
        method Action load_msg_bits(MESSAGE msg_bits);
		fifo_msg_in.enq(msg_bits);
	endmethod

	method ActionValue#(ENCODED) get_encoded();
                fifo_parity.deq();
		ENCODED parity_out_reversed;
		for (Integer i=0 ; i<valueOf(PARITY_LEN) ; i=i+1)
			parity_out_reversed[i] = fifo_parity.first[ valueOf(PARITY_LEN) - i - 1];
                return parity_out_reversed;
        endmethod

/*
        method ActionValue#(MESSAGE) get_encoded();
		fifo_encoded_out.deq();
		return fifo_encoded_out.first;
	endmethod
*/
endmodule: mkBCHEncoder

endpackage: BCH_encoder

