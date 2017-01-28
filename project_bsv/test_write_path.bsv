package test_write_path;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import SpecialFIFOs::*;
import RIO_code_scheme_common::*;
import RIO_code_scheme_write_path::*;
import Polar_codec_common_revised::*;
import noise_gen::*;

typedef 16 MAX_FRM_CNT;

typedef struct { Vector#(7, UInt#(32)) enc_err_cnt; UInt#(32) wl_cnt; } Enc_err_prob deriving(Bits, Eq);
typedef enum {INIT, ENCODING} State deriving(Bits, Eq);

interface TestWritePathIfc;
        method ActionValue#(Enc_err_prob) get_enc_err_prob();
endinterface


(* synthesize, options = "-no-aggressive-conditions" *)
module mkTestWritePath (TestWritePathIfc);
	RIOCodeSchemeWritePathIfc rio_code_write_path <- mkRIOCodeSchemeWritePath;

	NoiseGenIfc err_vec_gen_tx <- mkNoiseGen;
	
	Reg#(UInt#(32)) msg_in_cnt <- mkReg(0);
	Reg#(UInt#(32)) enc_out_cnt <- mkReg(0);
	Reg#(UInt#(3)) reg_page_num <- mkReg(0);
	Reg#(UInt#(4)) reg_frm_num <- mkReg(0);
        Reg#(UInt#(3)) reg_page_num_out <- mkReg(0);
        Reg#(UInt#(4)) reg_frm_num_out <- mkReg(0);
	FIFO#(Enc_err_prob) fifo_enc_err_prob <- mkPipelineFIFO;
	Reg#(Enc_err_prob) reg_enc_err_prob <- mkRegU;
	Reg#(Vector#(7, UInt#(8))) reg_enc_err_cnt <- mkRegU;
	Reg#(State) reg_state <- mkReg(INIT);

	rule init (reg_state == INIT);
		rio_code_write_path.setPageNum(reg_page_num);
		err_vec_gen_tx.set_threshold(32'h8000_0000);
		rio_code_write_path.setMaxFrmCnt(fromInteger(valueOf(MAX_FRM_CNT)));
		Enc_err_prob enc_err_prob;
		enc_err_prob.enc_err_cnt = replicate(0);
		enc_err_prob.wl_cnt = 0;
		reg_enc_err_prob <= enc_err_prob;

		reg_enc_err_cnt <= replicate(0);
		reg_state <= ENCODING;	
	endrule

        rule inputMessages (msg_in_cnt < zeroExtend(get_msg_bit_len(reg_page_num))*4 && reg_state == ENCODING);
		//Bit#(64) user_data =zeroExtend({pack(reg_frm_num), pack(msg_in_cnt)});
		Bit#(64) user_data <- err_vec_gen_tx.get_err_vec();
		rio_code_write_path.putUserdata(user_data);
                msg_in_cnt <= msg_in_cnt + 1;
        endrule

	rule reset_msg_in_cnt (msg_in_cnt == zeroExtend(get_msg_bit_len(reg_page_num))*4 && reg_state == ENCODING);
		msg_in_cnt <= 0;
		if (reg_frm_num < fromInteger(valueOf(MAX_FRM_CNT)-1)) begin
			reg_frm_num <= reg_frm_num + 1;
			rio_code_write_path.setPageNum(reg_page_num);
		end
		else begin
			reg_frm_num <= 0;
                        if (reg_page_num < 6) begin
                                reg_page_num <= reg_page_num + 1;
                                rio_code_write_path.setPageNum(reg_page_num + 1);
                        end
                        else begin
                                reg_page_num <= 0;
                                rio_code_write_path.setPageNum(0);
                        end
		end
	endrule
	(* mutually_exclusive = "get_enc_fail_cnt, reset_msg_out_cnt" *)
        rule get_enc_fail_cnt (reg_state == ENCODING);
                let enc_fail_cnt <- rio_code_write_path.getEncFailBitCnt();
		Vector#(7, UInt#(8)) enc_err_cnt = reg_enc_err_cnt;
		enc_err_cnt[reg_page_num_out] = (enc_fail_cnt > 0) ? (enc_err_cnt[reg_page_num_out] + 1) : enc_err_cnt[reg_page_num_out];
		reg_enc_err_cnt <= enc_err_cnt;
                //$display("RIO code 1st enc. fail cnt = %d", enc_fail_cnt);
        endrule

	rule displayEncOut (enc_out_cnt < fromInteger(valueOf(MAX_DATA_CNT)) && reg_state == ENCODING);
		//if (msg_out_cnt >= 100) begin
		let write_path_out <- rio_code_write_path.getEncoded();
		//end
		//if (enc_out_cnt == 16)
		//	$display("Write path out: [Page:%d][FRM:%d][%d] %b", reg_page_num_out, reg_frm_num_out, enc_out_cnt, write_path_out);
		enc_out_cnt <= enc_out_cnt + 1;
	endrule

        rule reset_msg_out_cnt (enc_out_cnt == fromInteger(valueOf(MAX_DATA_CNT)) && reg_state == ENCODING);
                enc_out_cnt <= 0;
                if (reg_frm_num_out < fromInteger(valueOf(MAX_FRM_CNT)-1)) begin
                        reg_frm_num_out <= reg_frm_num_out + 1;
                end
                else begin
                        reg_frm_num_out <= 0;
                        if (reg_page_num_out < 6) begin
                                reg_page_num_out <= reg_page_num_out + 1;
                        end
                        else begin
                                reg_page_num_out <= 0;
				reg_enc_err_cnt <= replicate(0);

				Enc_err_prob enc_err_prob = reg_enc_err_prob;
				for (Integer i=0 ; i<7 ; i=i+1)
	        	        	enc_err_prob.enc_err_cnt[i] = enc_err_prob.enc_err_cnt[i] + zeroExtend(reg_enc_err_cnt[i]);
        	        	enc_err_prob.wl_cnt = enc_err_prob.wl_cnt + 1;
				reg_enc_err_prob <= enc_err_prob;
				fifo_enc_err_prob.enq(enc_err_prob);				
                        end
                end
        endrule

	method ActionValue#(Enc_err_prob) get_enc_err_prob();
		fifo_enc_err_prob.deq();
		return fifo_enc_err_prob.first;
	endmethod

endmodule: mkTestWritePath
endpackage: test_write_path

