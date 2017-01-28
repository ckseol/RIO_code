package enc_fail_test;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import RIO_encoder_1st::*;
import RIO_decoder_1st::*;
import Xorshift128plus::*;
import Polar_codec_common_revised::*;


typedef enum {INIT_TEST, INIT_FRAME, INIT_PAGE, RAND_MSG_PREV_ENC_IN, WAITING_ENC_DEC_DONE, AGGREGATE_STATS} EncFailTestState deriving(Bits, Eq);

interface EncFailTestIfc;
	method ActionValue#(Vector#(8, UInt#(32))) get_enc_fail_result();
	method ActionValue#(Vector#(7, UInt#(32))) get_enc_fail_result_after_reencoding_dummy();
        method ActionValue#(Vector#(7, UInt#(14))) get_dec_fail_result();
endinterface


(* synthesize, options = "-no-aggressive-conditions" *)
module mkEncFailTest (EncFailTestIfc);

	RIOEncoder1stIfc rio_encoder_1st <- mkRIOEncoder1st;
	RIODecoder1stIfc rio_decoder_1st <- mkRIODecoder1st;
	Xorshift128plusIfc rand_msg_gen <- mkXorshift128plus;

	Reg#(EncFailTestState) reg_state <- mkReg(INIT_TEST);

	Reg#(UInt#(32)) reg_period_exponent <- mkReg(0);
	Reg#(UInt#(3)) reg_page_num <- mkReg(0);

	Reg#(UInt#(8)) reg_enc_input_msg_counter <- mkReg(0);
	Reg#(UInt#(7)) reg_enc_input_prevenc_counter <- mkReg(0);
	Reg#(UInt#(7)) reg_enc_output_counter <- mkReg(0);

	Reg#(UInt#(7)) reg_dec_input_counter <- mkReg(0);
	Reg#(UInt#(8)) reg_dec_output_counter <- mkReg(0);

	Vector#(64, Reg#(Bit#(256))) reg_prev_enc_buffer <- replicateM(mkReg(0));
	Vector#(128, Reg#(Bit#(64))) reg_user_data_buffer <- replicateM(mkReg(0));

	FIFO#(Bit#(256)) fifo_encoded_data <- mkPipelineFIFO;

	Reg#(Bit#(14)) reg_dec_fail_err_cnt <- mkReg(0);

	Reg#(Vector#(8, UInt#(32))) reg_enc_fail_cnt <- mkReg(replicate(0));
	Reg#(Vector#(7, UInt#(32))) reg_enc_fail_cnt_after_reencoding_dummy <- mkReg(replicate(0));
	Reg#(Vector#(7, UInt#(14))) reg_dec_fail_cnt <- mkReg(replicate(0));
	FIFO#(Vector#(8, UInt#(32))) fifo_enc_fail_result <- mkPipelineFIFO;
        FIFO#(Vector#(7, UInt#(32))) fifo_enc_fail_result_after_reencoding_dummy <- mkPipelineFIFO;
        FIFO#(Vector#(7, UInt#(14))) fifo_dec_fail_result <- mkPipelineFIFO;	

	Reg#(UInt#(32)) reg_frm_cnt <- mkReg(0);
	Reg#(Bool) reg_fill_dummy_data <- mkReg(False);

	rule init_test (reg_state == INIT_TEST);
		reg_period_exponent <= 7;
		reg_enc_fail_cnt <= replicate(0);
		reg_enc_fail_cnt_after_reencoding_dummy <= replicate(0);
		reg_frm_cnt <= 0;
		reg_state <= INIT_FRAME;
	endrule

	rule init_frame (reg_state == INIT_FRAME);
		reg_page_num <= 0;
		reg_frm_cnt <= reg_frm_cnt + 1;
		reg_state <= INIT_PAGE;
		reg_fill_dummy_data <= False;

                //rio_encoder_1st.set_page_num(0);
                //rio_decoder_1st.set_page_num(0);

		for (Integer i=0 ; i<64 ; i=i+1)
			reg_prev_enc_buffer[i] <= 0;
	endrule

        rule init_page (reg_state == INIT_PAGE);
		//if (reg_page_num > 0) begin
		rio_encoder_1st.set_page_num(reg_page_num);	
		//rio_decoder_1st.set_page_num(reg_page_num);
		//end
		reg_enc_input_msg_counter <= 0;
		reg_enc_input_prevenc_counter <= 0;
		reg_enc_output_counter <=0;

		reg_dec_input_counter <= 0;
		reg_dec_output_counter <= 0;
	
		reg_dec_fail_err_cnt <= 0;
		reg_state <= RAND_MSG_PREV_ENC_IN;
	endrule

	(* descending_urgency = "inputMessages, inputPrevenc, inputMessagesPrevencDone " *)
	rule inputMessages (reg_state == RAND_MSG_PREV_ENC_IN && reg_enc_input_msg_counter < get_msg_bit_len(reg_page_num)); 
		//rio_encoder_1st.load_msg(get_msg_bit(truncate(reg_input_msg_counter), page_num));
		//let rand_msg_in <- rand_msg_gen.get_val();
		if (reg_fill_dummy_data) begin 
			rio_encoder_1st.load_msg(64'd0);
			reg_user_data_buffer[reg_enc_input_msg_counter] <= 0;
		end
		else begin
			Bit#(64) rand_msg_in <- rand_msg_gen.get_val();
			rio_encoder_1st.load_msg(rand_msg_in);
			reg_user_data_buffer[reg_enc_input_msg_counter] <= rand_msg_in;
		//	$display("Encoder input [%d] %b", reg_enc_input_msg_counter, rand_msg_in);
		end
		
		//$display("MSG Page:%d, [%d] %b", page_num, input_msg_counter, get_msg_bit(truncate(input_msg_counter), page_num));
		reg_enc_input_msg_counter <= reg_enc_input_msg_counter + 1;
	endrule

        rule inputPrevenc (reg_state == RAND_MSG_PREV_ENC_IN && reg_page_num > 0 && reg_enc_input_prevenc_counter <= 7'd63);
		rio_encoder_1st.load_prev_enc(reg_prev_enc_buffer[reg_enc_input_prevenc_counter]);
		//$display("PREV_ENC Page:%d, [%d] %b", page_num, input_prevenc_counter, get_prev_enc_page(truncate(input_prevenc_counter), page_num));
                reg_enc_input_prevenc_counter <= reg_enc_input_prevenc_counter + 1;
        endrule

	rule inputMessagesPrevencDone (reg_state == RAND_MSG_PREV_ENC_IN);
		if (reg_enc_input_msg_counter == get_msg_bit_len(reg_page_num) && reg_page_num == 0)
			reg_state <= WAITING_ENC_DEC_DONE; 
		else if (reg_enc_input_msg_counter == get_msg_bit_len(reg_page_num) && reg_page_num > 0 && reg_enc_input_prevenc_counter == 7'd64)
			reg_state <= WAITING_ENC_DEC_DONE;
		else 
			reg_state <= RAND_MSG_PREV_ENC_IN;
	endrule

	(* descending_urgency = "getEncodedAndLoadDecoder, decoderInput, getDecoded, encDecDone" *)
	rule getEncodedAndLoadDecoder (reg_state == WAITING_ENC_DEC_DONE && reg_enc_output_counter <= 7'd63);
		let encoded_out_bluespec <- rio_encoder_1st.get_encoded();
               	reg_enc_output_counter <= reg_enc_output_counter + 1;
                fifo_encoded_data.enq(encoded_out_bluespec);
		reg_prev_enc_buffer[reg_enc_output_counter] <= encoded_out_bluespec;

		if (reg_enc_output_counter == 0) 
			rio_decoder_1st.set_page_num(reg_page_num);
		//	$display("Page[%d][%d]: %b", reg_page_num, reg_enc_output_counter, encoded_out_bluespec); 
        endrule

	rule decoderInput (reg_state == WAITING_ENC_DEC_DONE && reg_dec_input_counter <= 7'd63);
		//$display("Dec input: Page[%d][%d]: %b", reg_page_num, reg_dec_input_counter, fifo_encoded_data.first);
		rio_decoder_1st.load_encoded_bits(fifo_encoded_data.first); fifo_encoded_data.deq();
		reg_dec_input_counter <= reg_dec_input_counter + 1;
	endrule

	rule getDecoded (reg_state == WAITING_ENC_DEC_DONE && reg_dec_output_counter < get_msg_bit_len(reg_page_num));
                let decoder_out_bluespec <- rio_decoder_1st.get_decoded();
		//if (!reg_fill_dummy_data) begin	
			Bit#(64) err_vector = reg_user_data_buffer[reg_dec_output_counter] ^ decoder_out_bluespec;
			reg_dec_fail_err_cnt <= reg_dec_fail_err_cnt + zeroExtend(pack(countOnes(err_vector)));	
			//$display("Dec output: [%d] %b", reg_dec_output_counter, decoder_out_bluespec);
                        //$display("enc Input : [%d] %b", reg_dec_output_counter, reg_user_data_buffer[reg_dec_output_counter]);
		//end
                reg_dec_output_counter <= reg_dec_output_counter + 1;
	endrule

	rule encDecDone (reg_state == WAITING_ENC_DEC_DONE);
		if (reg_dec_output_counter == get_msg_bit_len(reg_page_num) && reg_enc_output_counter == 7'd64)
			reg_state <= AGGREGATE_STATS;
		else
			reg_state <= WAITING_ENC_DEC_DONE;
	endrule

	rule getStats (reg_state == AGGREGATE_STATS);
		let enc_fail_bit_cnt <-  rio_encoder_1st.get_enc_fail_bit_cnt();
		let reg_enc_fail_cnt_tmp =  reg_enc_fail_cnt;
		reg_enc_fail_cnt_tmp[reg_page_num]  =  reg_enc_fail_cnt_tmp[reg_page_num] + (enc_fail_bit_cnt > 0 ? 1 : 0);

		if (reg_fill_dummy_data) begin
                	let reg_enc_fail_cnt_after_reencoding_dummy_tmp =  reg_enc_fail_cnt_after_reencoding_dummy;
                	reg_enc_fail_cnt_after_reencoding_dummy_tmp[reg_page_num]  =  reg_enc_fail_cnt_after_reencoding_dummy_tmp[reg_page_num] + (enc_fail_bit_cnt > 0 ? 1 : 0);
			reg_enc_fail_cnt_after_reencoding_dummy <= reg_enc_fail_cnt_after_reencoding_dummy_tmp;			
		end
		//else begin
	                let reg_dec_fail_cnt_tmp =  reg_dec_fail_cnt;
			//$display("Dec fail count = %d", reg_dec_fail_err_cnt);
	                reg_dec_fail_cnt_tmp[reg_page_num]  =  reg_dec_fail_cnt_tmp[reg_page_num] + (reg_dec_fail_err_cnt > 0 ? 1 : 0);
			reg_dec_fail_cnt <= reg_dec_fail_cnt_tmp;
		//end

		if (enc_fail_bit_cnt > 0) begin
			reg_fill_dummy_data <= True;
		end
		else begin
			reg_fill_dummy_data <= False;
			//$display("Page: [%d] Encoding fail bit counter: %d", reg_page_num, enc_fail_bit_cnt);
			reg_page_num <= reg_page_num + 1;
		end
		if (reg_page_num < 6)
			reg_state <= INIT_PAGE;
		else begin
			//$display("[FRM%5d], enc fail bit cnt: %5d %5d %5d %5d %5d %5d %5d", 
			//	reg_frm_cnt, reg_enc_fail_cnt[0], reg_enc_fail_cnt[1], reg_enc_fail_cnt[2], reg_enc_fail_cnt[3],  reg_enc_fail_cnt[4], reg_enc_fail_cnt[5], reg_enc_fail_cnt_updated);
			reg_enc_fail_cnt_tmp[7] = reg_frm_cnt;
			fifo_enc_fail_result.enq(reg_enc_fail_cnt_tmp);
			fifo_enc_fail_result_after_reencoding_dummy.enq(reg_enc_fail_cnt_after_reencoding_dummy);
			fifo_dec_fail_result.enq(reg_dec_fail_cnt);
			reg_state <= INIT_FRAME;
		end
		reg_enc_fail_cnt <= reg_enc_fail_cnt_tmp;
	endrule

        method ActionValue#(Vector#(8, UInt#(32))) get_enc_fail_result();
		let enc_fail_result = fifo_enc_fail_result.first; 
		fifo_enc_fail_result.deq();
		return enc_fail_result;
	endmethod

        method ActionValue#(Vector#(7, UInt#(32))) get_enc_fail_result_after_reencoding_dummy();
                let enc_fail_result_after_reencoding_dummy = fifo_enc_fail_result_after_reencoding_dummy.first;
                fifo_enc_fail_result_after_reencoding_dummy.deq();
                return enc_fail_result_after_reencoding_dummy;
        endmethod

	method ActionValue#(Vector#(7, UInt#(14))) get_dec_fail_result();
                let dec_fail_result = fifo_dec_fail_result.first;
                fifo_dec_fail_result.deq();
                return dec_fail_result;
        endmethod


endmodule: mkEncFailTest
endpackage: enc_fail_test

