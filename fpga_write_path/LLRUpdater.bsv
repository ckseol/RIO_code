package LLRUpdater;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
//import RIO_subencoder_1st::*;

import Polar_codec_common_revised::*;

typedef Bit#(64) ENCODED;

interface LLRUpdaterIfc;
	method Action put_input(ENCODED prev_enc_in, ENCODED u_hat_in, Bit#(6) idx_in);
        method ActionValue#(LLR#(8)) get_llr();
endinterface: LLRUpdaterIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkLLRUpdater(LLRUpdaterIfc);

        FIFO#(LLR#(8)) fifo_llr <- mkPipelineFIFO;

	FIFO#(Bit#(2)) fifo_idx <- mkPipelineFIFO;
        FIFO#(Vector#(4, LLR#(6))) fifo_llr_N4 <- mkPipelineFIFO;
        FIFO#(Bit#(4)) fifo_u_hat_N4 <- mkPipelineFIFO;


        rule generate_final_LLR;// (startEncoding == True);
                let llr_N4 = fifo_llr_N4.first; fifo_llr_N4.deq();
                let u_hat_N4 = fifo_u_hat_N4.first; fifo_u_hat_N4.deq();
                let idx_in = fifo_idx.first; fifo_idx.deq();

                let u_hat_N2 = case(idx_in[1])
                                        1'b0: u_hat_N4[1:0];
                                        1'b1: u_hat_N4[3:2];
                                endcase;

                let s_hat_N2 = mulG2(u_hat_N4[1:0]);
                let llr_N2 = update_LLR_N2(llr_N4, s_hat_N2, idx_in[1]);

                let s_hat = u_hat_N2[0];
                let llr = llrUpdateN2(llr_N2[0], llr_N2[1], s_hat, idx_in[0]);

                fifo_llr.enq(llr);
        endrule

        method Action put_input(ENCODED prev_enc_in, ENCODED u_hat_in, Bit#(6) idx_in);

                let u_hat_tmp = u_hat_in; 
		let u_hat_N32 = case(idx_in[5])
					1'b0: u_hat_tmp[31:0];
					1'b1: u_hat_tmp[63:32];
				endcase;
                let u_hat_N16 = case(idx_in[4])
                                        1'b0: u_hat_N32[15:0];
                                        1'b1: u_hat_N32[31:16];
                                endcase;
                let u_hat_N8 = case(idx_in[3])
                                        1'b0: u_hat_N16[7:0];
                                        1'b1: u_hat_N16[15:8];
                                endcase;
                let u_hat_N4 = case(idx_in[2])
                                        1'b0: u_hat_N8[3:0];
                                        1'b1: u_hat_N8[7:4];
                                endcase;
//                let u_hat_N2 = case(idx_in[1])
  //                                      1'b0: u_hat_N4[1:0];
    //                                    1'b1: u_hat_N4[3:2];
      //                          endcase;

		
                let s_hat_N32 = mulG32(u_hat_tmp[31:0]);
                let llr_N32 = update_LLR_N32_init(prev_enc_in, s_hat_N32, idx_in[5]);

                let s_hat_N16 = mulG16(u_hat_N32[15:0]);
                let llr_N16 = update_LLR_N16(llr_N32, s_hat_N16, idx_in[4]);

                let s_hat_N8 = mulG8(u_hat_N16[7:0]);
                let llr_N8 = update_LLR_N8(llr_N16, s_hat_N8, idx_in[3]);

                let s_hat_N4 = mulG4(u_hat_N8[3:0]);
                let llr_N4 = update_LLR_N4(llr_N8, s_hat_N4, idx_in[2]);

                fifo_llr_N4.enq(llr_N4);
                fifo_u_hat_N4.enq(u_hat_N4);
                fifo_idx.enq(idx_in[1:0]);
		
/*
                let s_hat_N2 = mulG2(u_hat_N4[1:0]);
                let llr_N2 = update_LLR_N2(llr_N4, s_hat_N2, idx_in[1]);

                let s_hat = u_hat_N2[0];
                let llr = llrUpdateN2(llr_N2[0], llr_N2[1], s_hat, idx_in[0]);
		fifo_llr.enq(llr);*/
        endmethod

        method ActionValue#(LLR#(8)) get_llr();
		//$display("Output LLRs");
                fifo_llr.deq();
                return fifo_llr.first;
        endmethod

endmodule: mkLLRUpdater

endpackage: LLRUpdater
