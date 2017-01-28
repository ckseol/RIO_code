package Demapper;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RIO_subencoder_1st::*;
import Polar_codec_common_revised::*;

//`include "polar_codec_common.bsv"
//`include "encoder_config.bsv"



typedef 16 N_PAR_BIT_COLLECTOR;
typedef 4 SIZE_N_PAR_BIT_COLLECTOR;


interface SSerializerIfc;
	method Action putVector(Codeword decoded_subcodeword_in, UInt#(6) msg_ind_idx, UInt#(3) page_num);
	method ActionValue#(bit) getBit();
endinterface: SSerializerIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkSSerializer(SSerializerIfc);
        FIFO#(MSG_IND_IDX) fifo_msg_ind_idx <- mkPipelineFIFO;
        FIFO#(PAGE_NUM) fifo_page_num <- mkPipelineFIFO;
	
        FIFO#(UInt#(9)) fifo_bit_cnt <- mkPipelineFIFO;
        FIFO#(UInt#(8)) fifo_1_end_ind <- mkPipelineFIFO;

        FIFO#(Codeword) fifo_decoded_subcodeword_in <- mkPipelineFIFO;
        FIFO#(bit) fifo_bit_out <- mkPipelineFIFO;
        Reg#(UInt#(8)) bit_idx <- mkReg(0);

        rule serialize;
                let decoded_subcodeword = fifo_decoded_subcodeword_in.first;
		let msg_ind = get_msg_bit_ind(fifo_msg_ind_idx.first, fifo_page_num.first); 
                if (bit_idx <= fifo_1_end_ind.first) begin
			if (msg_ind[bit_idx] == 1'b1)
                        	fifo_bit_out.enq(decoded_subcodeword[bit_idx]);
		end
                if (bit_idx == fifo_1_end_ind.first) begin
                        fifo_decoded_subcodeword_in.deq();
			fifo_msg_ind_idx.deq();
			fifo_page_num.deq();
			fifo_bit_cnt.deq();
			fifo_1_end_ind.deq();
                        bit_idx <= 0;
                end
                else begin
                        bit_idx <= bit_idx + 1;
                end
        endrule

        method Action putVector(Codeword decoded_subcodeword_in, UInt#(6) msg_ind_idx, UInt#(3) page_num);
                Vector#(Codeword_len, bit) msg_ind_vec;
		Codeword msg_ind = get_msg_bit_ind(msg_ind_idx, page_num);
                for (Integer i=0 ; i<valueOf(Codeword_len) ; i=i+1)
                        msg_ind_vec[i] = msg_ind[i];
                let countOneVal = countOnes(msg_ind);
                if (countOneVal > 0) begin
                        let start_idx = findElem(1'b1, msg_ind_vec);
                        let end_idx = findElem(1'b1, reverse(msg_ind_vec));
                        if (isValid(start_idx))
                                bit_idx <= fromMaybe(?, start_idx);
                        else
                                bit_idx <= 0;

                        if (isValid(end_idx))
                                fifo_1_end_ind.enq(fromInteger(valueOf(Codeword_len)-1)-fromMaybe(?, end_idx));
                        //$display("%d, %d, %d", countOnes(msg_ind), fromMaybe(?, start_idx), fromMaybe(?, end_idx));
                        //fifo_msg_msg_cnt_in.enq(msg_msg_cnt_in);
		        fifo_msg_ind_idx.enq(msg_ind_idx);
			fifo_page_num.enq(page_num);
                	fifo_bit_cnt.enq(zeroExtend(countOneVal));	
			fifo_decoded_subcodeword_in.enq(decoded_subcodeword_in);
                end
        endmethod

        method ActionValue#(bit) getBit();
                let bit_out = fifo_bit_out.first;
		//$display("[Serializer] %b", bit_out);
                fifo_bit_out.deq();
                return bit_out;
        endmethod
endmodule: mkSSerializer


interface BitCollectorIfc;
	method Action putDecVec(Codeword decoded_subcodeword_in, UInt#(6) msg_ind_idx, UInt#(3) page_num); 
	method ActionValue#(MSG_MSG_CNT) getCollectedBits();
endinterface

(* synthesize, options = "-no-aggressive-conditions" *)
module mkBitCollector(BitCollectorIfc);
	SSerializerIfc serializer <- mkSSerializer;
	FIFO#(MSG_MSG_CNT) fifo_msg_msg_cnt_out <- mkPipelineFIFO;
	FIFO#(UInt#(9)) fifo_bit_cnt <- mkPipelineFIFO;	
	Reg#(Codeword) reg_bit_collected <- mkReg(0);
	Reg#(UInt#(9)) reg_bit_cnt <- mkReg(0);

	rule serializer_to_out (reg_bit_cnt < fifo_bit_cnt.first);
		bit current_bit <- serializer.getBit();
		reg_bit_collected[reg_bit_cnt] <= current_bit;
		reg_bit_cnt <= reg_bit_cnt + 1;
	endrule

        rule serializer_to_out_done (reg_bit_cnt == fifo_bit_cnt.first);
                //$display("Bit Collector: %b, [%d]", reg_bit_collected, fifo_bit_cnt.first);
                MSG_MSG_CNT msg_msg_cnt;
                msg_msg_cnt.msg_vec = reg_bit_collected;
                msg_msg_cnt.msg_cnt = fifo_bit_cnt.first;
                fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
                fifo_bit_cnt.deq();
                reg_bit_cnt <= 0;
        endrule

		
        method Action putDecVec(Codeword decoded_subcodeword_in, UInt#(6) msg_ind_idx, UInt#(3) page_num);
		let countOneVal = countOnes(get_msg_bit_ind(msg_ind_idx, page_num));
		if (countOneVal == fromInteger(valueOf(Codeword_len))) begin
			MSG_MSG_CNT msg_msg_cnt;
			msg_msg_cnt.msg_vec = decoded_subcodeword_in;
			msg_msg_cnt.msg_cnt = countOneVal;
			fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
		end
		else if (countOneVal > 0) begin
			serializer.putVector(decoded_subcodeword_in, msg_ind_idx, page_num);
			fifo_bit_cnt.enq(countOneVal);
		end
		else if (countOneVal == 0) begin
                        MSG_MSG_CNT msg_msg_cnt;
                        msg_msg_cnt.msg_vec = 0;
                        msg_msg_cnt.msg_cnt = 0;
                        fifo_msg_msg_cnt_out.enq(msg_msg_cnt);	
		end	
	endmethod

        method ActionValue#(MSG_MSG_CNT) getCollectedBits();
		let msg_msg_cnt_out = fifo_msg_msg_cnt_out.first;
		fifo_msg_msg_cnt_out.deq();
		return msg_msg_cnt_out;
	endmethod
endmodule


interface MergerIfc;
	method Action putMsgVec(MSG_MSG_CNT msg_msg_cnt);
	method Action resetOffset();
	method ActionValue#(MESSAGE) getMsg();
endinterface

(* synthesize, options = "-no-aggressive-conditions" *)
module mkMerger(MergerIfc);
	FIFO#(MSG_MSG_CNT) fifo_msg_msg_cnt_in <- mkPipelineFIFO;
	FIFO#(MESSAGE) fifo_msg_out <- mkPipelineFIFO;
	Reg#(MESSAGE) reg_collected_bits <- mkReg(0);
	Reg#(UInt#(9)) reg_offset <- mkReg(0);
	
        rule combine_msg_bits_main;
                let msg_msg_cnt_in = fifo_msg_msg_cnt_in.first; fifo_msg_msg_cnt_in.deq();
		let end_idx = reg_offset + msg_msg_cnt_in.msg_cnt;
                MESSAGE msg_vec = msg_msg_cnt_in.msg_vec;
                MESSAGE mask = '1 << reg_offset;
                let current_collected_bits = reg_collected_bits;
                current_collected_bits = (current_collected_bits & (~mask) ) | ((msg_vec << reg_offset) & mask);
		//$display("Merger: %b, [%d], offset %d", msg_msg_cnt_in.msg_vec, msg_msg_cnt_in.msg_cnt, reg_offset);
		if (end_idx > fromInteger(valueOf(Codeword_len)-1)) begin
			let prev_len = fromInteger(valueOf(Codeword_len)) - reg_offset;
			MESSAGE msg_vec_remainder = msg_vec >> prev_len;
			fifo_msg_out.enq(current_collected_bits);
                        reg_collected_bits <= msg_vec_remainder;
			reg_offset <= end_idx - fromInteger(valueOf(Codeword_len));
		end
		else begin
			reg_collected_bits <= current_collected_bits;
			reg_offset <= end_idx;	
		end	
	endrule

	method Action putMsgVec(MSG_MSG_CNT msg_msg_cnt);
		//$display("Merger: %b, [%d]", msg_msg_cnt.msg_vec, msg_msg_cnt.msg_cnt);
		if (msg_msg_cnt.msg_cnt > 0)
			fifo_msg_msg_cnt_in.enq(msg_msg_cnt);
	endmethod

	method Action resetOffset();
		reg_offset <= 0;
	endmethod

        method ActionValue#(MESSAGE) getMsg();
		let msg_out = fifo_msg_out.first;
		fifo_msg_out.deq();
		return msg_out;
	endmethod
endmodule



interface DemapperIfc;
	method Action setPageNum(PAGE_NUM page_num);
	//method PAGE_NUM getPageNum();
        method Action putDecVec(Codeword decoded_subcodeword_in);
        method ActionValue#(MESSAGE) getDemappedOut();
endinterface

(* synthesize, options = "-no-aggressive-conditions" *)
module mkDemapper(DemapperIfc);	
	Vector#(N_PAR_BIT_COLLECTOR, BitCollectorIfc) vector_bit_collector <- replicateM(mkBitCollector);
	Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(Codeword)) vector_fifo_bit_collector_in <- replicateM(mkGLFIFOF(True, False));
	Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(UInt#(6))) vector_fifo_msg_ind_cnt_in <- replicateM(mkGLFIFOF(True, False));
	Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(UInt#(3))) vector_fifo_page_num_in <- replicateM(mkGLFIFOF(True, False));

        Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(MSG_MSG_CNT)) vector_fifo_bit_collector_out <- replicateM(mkGLFIFOF(False, True));
	
	MergerIfc merger <- mkMerger;
	FIFO#(Codeword) fifo_subcodeword_in <- mkPipelineFIFO;

	//Reg#(PAGE_NUM) reg_page_num <- mkReg(0);
	FIFO#(PAGE_NUM) fifo_page_num <- mkFIFO1;
	Reg#(UInt#(7)) reg_msg_ind_counter <- mkReg(0);
	
	Reg#(UInt#(SIZE_N_PAR_BIT_COLLECTOR)) reg_in_fifo_cnt <- mkReg(0);
        Reg#(UInt#(SIZE_N_PAR_BIT_COLLECTOR)) reg_out_fifo_cnt <- mkReg(0);

	FIFO#(MESSAGE) fifo_demapped_out <- mkPipelineFIFO;

	//rule input_fifo_to_multiple_fifos (reg_msg_ind_counter <= 8'd255 && vector_fifo_bit_collector_in[reg_in_fifo_cnt].notFull);
        rule input_fifo_to_multiple_fifos (reg_msg_ind_counter <= 63 && vector_fifo_bit_collector_in[reg_in_fifo_cnt].notFull);
		let subcodeword_in = fifo_subcodeword_in.first; fifo_subcodeword_in.deq();
		vector_fifo_bit_collector_in[reg_in_fifo_cnt].enq(subcodeword_in);
		vector_fifo_msg_ind_cnt_in[reg_in_fifo_cnt].enq(truncate(reg_msg_ind_counter));
		vector_fifo_page_num_in[reg_in_fifo_cnt].enq(fifo_page_num.first);
		if (reg_in_fifo_cnt < fromInteger(valueOf(N_PAR_BIT_COLLECTOR)-1))
			reg_in_fifo_cnt <= reg_in_fifo_cnt + 1;
		else
			reg_in_fifo_cnt <= 0;
		
		if (reg_msg_ind_counter < 63)
			reg_msg_ind_counter <= reg_msg_ind_counter + 1;
		else begin
			reg_msg_ind_counter <= 0;
			fifo_page_num.deq();
		end
		//$display("[Page:%d], %d", fifo_page_num.first, reg_msg_ind_counter);
	endrule

        for (Integer i=0 ; i<valueOf(N_PAR_BIT_COLLECTOR) ; i=i+1)
        rule fifo_to_bit_collector (vector_fifo_bit_collector_in[i].notEmpty && vector_fifo_msg_ind_cnt_in[i].notEmpty && vector_fifo_page_num_in[i].notEmpty);
		//let current_msg_ind = get_msg_bit_ind(vector_fifo_msg_ind_cnt_in[i].first , reg_page_num);
               	vector_bit_collector[i].putDecVec(vector_fifo_bit_collector_in[i].first, vector_fifo_msg_ind_cnt_in[i].first, vector_fifo_page_num_in[i].first);
               	vector_fifo_bit_collector_in[i].deq();
		vector_fifo_msg_ind_cnt_in[i].deq();
		vector_fifo_page_num_in[i].deq();
	endrule
/*
        rule fifo_to_bit_collector_last (vector_fifo_bit_collector_in[ valueOf(N_PAR_BIT_COLLECTOR)-1].notEmpty && vector_fifo_msg_ind_cnt_in[ valueOf(N_PAR_BIT_COLLECTOR)-1].notEmpty);
                //let current_msg_ind = get_msg_bit_ind(vector_fifo_msg_ind_cnt_in[i].first , reg_page_num);
		Integer last_idx = valueOf(N_PAR_BIT_COLLECTOR)-1;
                vector_bit_collector[last_idx].putDecVec(vector_fifo_bit_collector_in[last_idx].first, vector_fifo_msg_ind_cnt_in[last_idx].first, fifo_page_num.first);
                vector_fifo_bit_collector_in[last_idx].deq();
                vector_fifo_msg_ind_cnt_in[last_idx].deq();
        endrule
*/
	
	for (Integer i=0 ; i<valueOf(N_PAR_BIT_COLLECTOR) ; i=i+1)
	rule bit_collector_to_fifo (vector_fifo_bit_collector_out[i].notFull);
		let msg_msg_cnt <- vector_bit_collector[i].getCollectedBits();
		vector_fifo_bit_collector_out[i].enq(msg_msg_cnt);
	endrule
	
	rule multiple_fifos_to_merger (vector_fifo_bit_collector_out[reg_out_fifo_cnt].notEmpty);
		let msg_msg_cnt = vector_fifo_bit_collector_out[reg_out_fifo_cnt].first;
		vector_fifo_bit_collector_out[reg_out_fifo_cnt].deq();
		merger.putMsgVec(msg_msg_cnt);
                if (reg_out_fifo_cnt < fromInteger(valueOf(N_PAR_BIT_COLLECTOR)-1))
       	                reg_out_fifo_cnt <= reg_out_fifo_cnt + 1;
       	        else
               	        reg_out_fifo_cnt <= 0;
	endrule
/*
        rule get_merger_output;
                let demapped_out <- merger.getMsg();
                fifo_demapped_out.enq(demapped_out);
                if (reg_demapped_out_cnt == get_msg_bit_len(fifo_page_num.first)-1) begin
                        fifo_page_num.deq();
                        reg_demapped_out_cnt <= 0;
                end
                else
                        reg_demapped_out_cnt <= reg_demapped_out_cnt + 1;
        endrule
*/

        method Action setPageNum(PAGE_NUM page_num);
		//reg_page_num <= page_num;
		fifo_page_num.enq(page_num);
	endmethod

        method Action putDecVec(Codeword subcodeword_in);
		//if (fifo_page_num.first >=0)
		fifo_subcodeword_in.enq(subcodeword_in);
	endmethod

        method ActionValue#(MESSAGE) getDemappedOut();
		let demapped_out <- merger.getMsg();
		//$display("Page[%d] %b", fifo_page_num.first, demapped_out); 
		return demapped_out;
		//fifo_demapped_out.deq();
		//return fifo_demapped_out.first;
	endmethod
endmodule

endpackage: Demapper 
