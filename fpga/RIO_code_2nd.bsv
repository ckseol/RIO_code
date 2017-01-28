package RIO_code_2nd;

import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

`include "polar_codec_common_revised_2nd.bsv"

function Vector#(8, LLR#(4)) cascadedLLRUpdateN32(Codeword prevEncodedPage, Bit#(3) subCWCount, Codeword u_hat);
        Vector#(16, LLR#(3)) llr1;
        Vector#(8, LLR#(4))  llr2;
        Bit#(16) s1;
        Bit#(8) s2;
        s1 =    mulG16(u_hat[15:0]);
        s2 =    mulG8(case (subCWCount[2])
                        0: u_hat[7:0];
                        1: u_hat[23:16];
                endcase);
        for (Integer i=0 ; i<16 ; i=i+1)
                llr1[i] = initLLRUpdateN2(prevEncodedPage[i], prevEncodedPage[i+16], s1[i], subCWCount[2]);
        for (Integer i=0 ; i<8 ; i=i+1)
                llr2[i] = llrUpdateN2(llr1[i], llr1[i+8], s2[i], subCWCount[1]);
        return llr2;
endfunction: cascadedLLRUpdateN32

function Vector#(4, LLR#(m)) cascadedLLRUpdateN8(Vector#(8, LLR#(n)) llr2, Bit#(3) subCWCount, Codeword u_hat) provisos(Add#(n,1,m));
        Vector#(4, LLR#(m)) llr3;
        Bit#(4) s3;
        s3 =    mulG4(case (subCWCount[2:1])
                        2'b00: u_hat[3:0];
                        2'b01: u_hat[11:8];
                        2'b10: u_hat[19:16];
                        2'b11: u_hat[27:24];
                endcase);
        for (Integer i=0 ; i<4 ; i=i+1)
                llr3[i] = llrUpdateN2(llr2[i], llr2[i+4], s3[i], subCWCount[0]);
        return llr3;
endfunction: cascadedLLRUpdateN8

function Bool checkEncSuccessFail(Codeword encoded, Codeword prevEncodedPageBits);
        UInt#(6) failBitCount = countOnes(prevEncodedPageBits & (~encoded));
        return (failBitCount == 0) ? True : False;
endfunction


interface RIOEncoder2ndIfc;
        method Action loadMessage(Message iMsgBits);
        method Action loadPrevEnc(Codeword iPreEncodedPageBits);
	method ActionValue#(Codeword) getEncodedResult();
	//method ActionValue#(Bool) getEncSuccessFail();
endinterface: RIOEncoder2ndIfc

typedef enum {IDLE, ENC_RUNNING, ENC_DONE} State deriving(Bits, Eq);


(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIOEncoder2nd(RIOEncoder2ndIfc);
	FIFO#(Codeword) fifo_prevEncodedPageBits <- mkBypassFIFO;
	FIFO#(Message) fifo_msgBits <- mkBypassFIFO;
	// step 1
	FIFO#(Codeword) fifo_prev_enc_bits_step1 <- mkPipelineFIFO;
	FIFO#(Vector#(8, LLR#(4))) fifo_llr_N8_step1 <- mkPipelineFIFO;
	FIFO#(Message) fifo_msg_bits_step1 <- mkPipelineFIFO;
	
	// step 2
        FIFO#(Codeword) fifo_prev_enc_bits_step2 <- mkPipelineFIFO;
        FIFO#(Vector#(4, LLR#(5))) fifo_llr_N4_s0_step2 <- mkPipelineFIFO;
        FIFO#(Vector#(4, LLR#(5))) fifo_llr_N4_s1_step2 <- mkPipelineFIFO;
        FIFO#(Bit#(7)) fifo_msg_bits_step2 <- mkPipelineFIFO;

        // step 3
        FIFO#(Codeword) fifo_prev_enc_bits_step3 <- mkPipelineFIFO;
        FIFO#(Bit#(10)) fifo_msg_bits_step3 <- mkPipelineFIFO;

        // step 4
        FIFO#(Codeword) fifo_prev_enc_bits_step4 <- mkPipelineFIFO;
        FIFO#(Bit#(10)) fifo_msg_bits_step4 <- mkPipelineFIFO;
	FIFO#(Vector#(8, LLR#(4))) fifo_llr_N8_step4 <- mkPipelineFIFO;

        // step 5
        FIFO#(Codeword) fifo_prev_enc_bits_step5 <- mkPipelineFIFO;
        FIFO#(Bit#(17)) fifo_msg_bits_step5 <- mkPipelineFIFO;
	
        // step 6
        FIFO#(Codeword) fifo_prev_enc_bits_step6 <- mkPipelineFIFO;
        FIFO#(Bit#(17)) fifo_msg_bits_step6 <- mkPipelineFIFO;
	FIFO#(Vector#(8, LLR#(4))) fifo_llr_N8_step6 <- mkPipelineFIFO;

        // step 7
        FIFO#(Codeword) fifo_prev_enc_bits_step7 <- mkPipelineFIFO;
        FIFO#(Bit#(24)) fifo_msg_bits_step7 <- mkPipelineFIFO;

        // step 8
	FIFO#(Codeword) fifo_prev_enc_bits_step8 <- mkPipelineFIFO;
        FIFO#(Bit#(24)) fifo_msg_bits_step8 <- mkPipelineFIFO;
        FIFO#(Vector#(8, LLR#(4))) fifo_llr_N8_step8 <- mkPipelineFIFO;

	// step 9
	FIFO#(Codeword) fifo_prev_enc_bits_step9 <- mkPipelineFIFO;
	FIFO#(Codeword) fifo_msg_bits_step9 <- mkPipelineFIFO;

	// final step
	FIFO#(Codeword) encodedBits <- mkPipelineFIFO;
	//FIFO#(Bool) encSuccessFail <- mkPipelineFIFO;

	rule gen_first_8_LLRs_step1;
		Codeword prevEncodedPage = fifo_prevEncodedPageBits.first; fifo_prevEncodedPageBits.deq();
		Message i_msg = fifo_msgBits.first; fifo_msgBits.deq();
		Codeword u_hat = 32'd0;
		u_hat[0] = i_msg[0];
                u_hat[1] = i_msg[1];
                u_hat[2] = i_msg[2];
                u_hat[4] = i_msg[3];
                u_hat[8] = i_msg[4];
                u_hat[16] = i_msg[5];
		let llr_N8 = cascadedLLRUpdateN32(prevEncodedPage, 3'b000, u_hat);
		fifo_prev_enc_bits_step1.enq(prevEncodedPage);
		fifo_llr_N8_step1.enq(llr_N8);
		fifo_msg_bits_step1.enq(i_msg);		
	endrule

	rule det_first_4_bits_step2;
		Codeword prevEncodedPage = fifo_prev_enc_bits_step1.first; fifo_prev_enc_bits_step1.deq();
		Message i_msg = fifo_msg_bits_step1.first; fifo_msg_bits_step1.deq();
		let llr_N8 = fifo_llr_N8_step1.first; fifo_llr_N8_step1.deq();
		let llr_N4_f = update_LLR_N4(llr_N8, 4'b0000, 1'b0);
		let encoded_N4 = repEncoderN4(llr_N4_f, i_msg[2:0]);		
		fifo_prev_enc_bits_step2.enq(prevEncodedPage);
		fifo_llr_N4_s0_step2.enq(update_LLR_N4(llr_N8, 4'b0000, 1'b1));
		fifo_llr_N4_s1_step2.enq(update_LLR_N4(llr_N8, 4'b1111, 1'b1));
		fifo_msg_bits_step2.enq({i_msg[5:3], encoded_N4});	
	endrule

	rule det_second_4_bits_step3;
                Codeword prevEncodedPage = fifo_prev_enc_bits_step2.first; fifo_prev_enc_bits_step2.deq();
                let i_msg = fifo_msg_bits_step2.first; fifo_msg_bits_step2.deq();
		let llr_N4_s0 = fifo_llr_N4_s0_step2.first; fifo_llr_N4_s0_step2.deq();
		let llr_N4_s1 = fifo_llr_N4_s1_step2.first; fifo_llr_N4_s1_step2.deq();		 
		let s_hat = mulG4(i_msg[3:0]);
		Vector#(4, LLR#(5)) llr_N4;
		for (Integer i=0 ; i<4 ; i=i+1)
			llr_N4[i] = (s_hat[i] == 0) ? llr_N4_s0[i] : llr_N4_s1[i];
		let encoded_N4 = spcEncoderN4(llr_N4, i_msg[4]);
		fifo_prev_enc_bits_step3.enq(prevEncodedPage);
                fifo_msg_bits_step3.enq({i_msg[6:5], encoded_N4, i_msg[3:0]});
	endrule

	rule gen_second_8_LLRs_step4;
                Codeword prevEncodedPage = fifo_prev_enc_bits_step3.first; fifo_prev_enc_bits_step3.deq();
                let i_msg = fifo_msg_bits_step3.first; fifo_msg_bits_step3.deq();		
                Codeword u_hat = 32'd0;
                u_hat[8:0] = i_msg[8:0];
                u_hat[16] = i_msg[9];		
		let llr_N8 = cascadedLLRUpdateN32(prevEncodedPage, 3'b010, u_hat);
                fifo_prev_enc_bits_step4.enq(prevEncodedPage);
                fifo_msg_bits_step4.enq(i_msg);		
		fifo_llr_N8_step4.enq(llr_N8);
	endrule

        rule det_second_8_bits_step5;
                Codeword prevEncodedPage = fifo_prev_enc_bits_step4.first; fifo_prev_enc_bits_step4.deq();
                let i_msg = fifo_msg_bits_step4.first; fifo_msg_bits_step4.deq();
		let llr_N8 = fifo_llr_N8_step4.first; fifo_llr_N8_step4.deq();
                let encoded_N8 = spcEncoderN8(llr_N8, i_msg[8]);
                fifo_prev_enc_bits_step5.enq(prevEncodedPage);
                fifo_msg_bits_step5.enq({i_msg[9], encoded_N8, i_msg[7:0]});
        endrule

        rule gen_third_8_LLRs_step6;
                Codeword prevEncodedPage = fifo_prev_enc_bits_step5.first; fifo_prev_enc_bits_step5.deq();
                let i_msg = fifo_msg_bits_step5.first; fifo_msg_bits_step5.deq();
                Codeword u_hat = 32'd0;
                u_hat[16:0] = i_msg;
                let llr_N8 = cascadedLLRUpdateN32(prevEncodedPage, 3'b100, u_hat);		
                fifo_prev_enc_bits_step6.enq(prevEncodedPage);
                fifo_msg_bits_step6.enq(i_msg);
		fifo_llr_N8_step6.enq(llr_N8);
        endrule
	
        rule det_third_8_bits_step7;
                Codeword prevEncodedPage = fifo_prev_enc_bits_step6.first; fifo_prev_enc_bits_step6.deq();
                let i_msg = fifo_msg_bits_step6.first; fifo_msg_bits_step6.deq();
                let llr_N8 = fifo_llr_N8_step6.first; fifo_llr_N8_step6.deq();
                let encoded_N8 = spcEncoderN8(llr_N8, i_msg[16]);
                fifo_prev_enc_bits_step7.enq(prevEncodedPage);
                fifo_msg_bits_step7.enq({encoded_N8, i_msg[15:0]});
        endrule

	rule gen_last_8_LLRs_step8;
                Codeword prevEncodedPage = fifo_prev_enc_bits_step7.first; fifo_prev_enc_bits_step7.deq();
                let i_msg = fifo_msg_bits_step7.first; fifo_msg_bits_step7.deq();
                Codeword u_hat = 32'd0;
                u_hat[23:0] = i_msg;
                let llr_N8 = cascadedLLRUpdateN32(prevEncodedPage, 3'b110, u_hat);
		fifo_prev_enc_bits_step8.enq(prevEncodedPage);
                fifo_msg_bits_step8.enq(i_msg);
                fifo_llr_N8_step8.enq(llr_N8);
	endrule
	
	rule det_last_8_nmsg_bits_step9;
		Codeword prevEncodedPage = fifo_prev_enc_bits_step8.first; fifo_prev_enc_bits_step8.deq();
                let i_msg = fifo_msg_bits_step8.first; fifo_msg_bits_step8.deq();
                let llr_N8 = fifo_llr_N8_step8.first; fifo_llr_N8_step8.deq();
                let encoded_N8 = rate0EncoderN8(llr_N8);
		fifo_prev_enc_bits_step9.enq(prevEncodedPage);
                fifo_msg_bits_step9.enq({encoded_N8, i_msg});		
	endrule

	rule gen_enc_bits_check_SF_final_step;
		Codeword prevEncodedPage = fifo_prev_enc_bits_step9.first; fifo_prev_enc_bits_step9.deq();
		Codeword encoded = mulG32(fifo_msg_bits_step9.first); fifo_msg_bits_step9.deq();
		let encFailErrorVector = prevEncodedPage & (~encoded);
		encodedBits.enq(encoded | encFailErrorVector);
		//$display("RIO 2nd enc fail: encoded: %b, prev: %b",encoded,prevEncodedPage); 
		//$display("RIO 2nd enc fail: %d", checkEncSuccessFail(encoded, prevEncodedPage));		
		//encSuccessFail.enq(checkEncSuccessFail(encoded, prevEncodedPage));
	endrule	

        method Action loadMessage(Message iMsgBits);
		fifo_msgBits.enq(iMsgBits);
        endmethod

        method Action loadPrevEnc(Codeword iPreEncodedPageBits);
                fifo_prevEncodedPageBits.enq(iPreEncodedPageBits);
        endmethod

        method ActionValue#(Codeword) getEncodedResult;
		let encodedResult = encodedBits.first; 
		encodedBits.deq();
                return encodedResult;
        endmethod
	/*
        method ActionValue#(Bool) getEncSuccessFail();
		let encSF = encSuccessFail.first;
		encSuccessFail.deq();
		return encSF;
	endmethod
	*/		
endmodule: mkRIOEncoder2nd


interface RIODecoder2ndIfc;
        method Action loadEncodedBits(Codeword iEncodedBits);
        method ActionValue#(Message) getDecodedResult();
endinterface: RIODecoder2ndIfc


(* synthesize, options = "-no-aggressive-conditions" *)
module mkRIODecoder2nd(RIODecoder2ndIfc);
	FIFO#(Codeword) encodedBits <- mkBypassFIFO;
	FIFO#(Message) decodedResult <- mkPipelineFIFO;

	rule decoding;
		let decoded = mulG32(encodedBits.first); encodedBits.deq();
		Message msgHat;
                msgHat[0] = decoded[0];
                msgHat[1] = decoded[1];
                msgHat[2] = decoded[2];
                msgHat[3] = decoded[4];
                msgHat[4] = decoded[8];
                msgHat[5] = decoded[16];
		decodedResult.enq(msgHat);
	endrule: decoding

	method Action loadEncodedBits(Codeword iEncodedBits);
		encodedBits.enq(iEncodedBits);
	endmethod

	method ActionValue#(Message) getDecodedResult();
		Message msgHat = decodedResult.first; decodedResult.deq();
		return msgHat;
	endmethod
endmodule: mkRIODecoder2nd

endpackage: RIO_code_2nd
