package Demapper;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RIO_subencoder_1st::*;
import Polar_codec_common_revised::*;

//`include "polar_codec_common.bsv"
//`include "encoder_config.bsv"


typedef struct {Bit#(n) msg_vec; UInt#(m) msg_cnt;} MSG_MSG_CNT#(numeric type n, numeric type m) deriving(Bits, Eq);


typedef 16 N_PAR_BIT_COLLECTOR;
typedef 4 SIZE_N_PAR_BIT_COLLECTOR;


interface SSerializerIfc#(type n);
	method Action putVector(Bit#(n) decoded_subcodeword_in, Bit#(n) msg_ind);
	method ActionValue#(bit) getBit();
endinterface: SSerializerIfc

module mkSSerializer(SSerializerIfc#(n)) provisos (Log#(TAdd#(1, n), m), Log#(n, l), Add#(l, 1, m), Add#(TLog#(n), 1, m));
        FIFO#(Bit#(n)) fifo_msg_ind <- mkPipelineFIFO;
	
        FIFO#(UInt#(m)) fifo_bit_cnt <- mkPipelineFIFO;
        FIFO#(UInt#(l)) fifo_1_end_ind <- mkPipelineFIFO;

        FIFO#(Bit#(n)) fifo_decoded_subcodeword_in <- mkPipelineFIFO;
        FIFO#(bit) fifo_bit_out <- mkPipelineFIFO;
        Reg#(UInt#(l)) bit_idx <- mkReg(0);

        rule serialize;
                let decoded_subcodeword = fifo_decoded_subcodeword_in.first;
		let msg_ind = fifo_msg_ind.first; 
                if (bit_idx <= fifo_1_end_ind.first) begin
			if (msg_ind[bit_idx] == 1'b1)
                        	fifo_bit_out.enq(decoded_subcodeword[bit_idx]);
		end
                if (bit_idx == fifo_1_end_ind.first) begin
                        fifo_decoded_subcodeword_in.deq();
			fifo_msg_ind.deq();
			fifo_bit_cnt.deq();
			fifo_1_end_ind.deq();
                        bit_idx <= 0;
                end
                else begin
                        bit_idx <= bit_idx + 1;
                end
        endrule

        method Action putVector(Bit#(n) decoded_subcodeword_in, Bit#(n) msg_ind);
                Vector#(n, bit) msg_ind_vec;
                for (Integer i=0 ; i<valueOf(n) ; i=i+1)
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
                                fifo_1_end_ind.enq(fromInteger(valueOf(n)-1)-fromMaybe(?, end_idx));
                        //$display("%d, %d, %d", countOnes(msg_ind), fromMaybe(?, start_idx), fromMaybe(?, end_idx));
                        //fifo_msg_msg_cnt_in.enq(msg_msg_cnt_in);
		        fifo_msg_ind.enq(msg_ind);
                	fifo_bit_cnt.enq(zeroExtend(countOneVal));	
			fifo_decoded_subcodeword_in.enq(decoded_subcodeword_in);
                end
        endmethod

        method ActionValue#(bit) getBit();
                fifo_bit_out.deq();
                return fifo_bit_out.first;
        endmethod
endmodule: mkSSerializer


interface BitCollectorIfc#(type n, type m);
	method Action putDecVec(Bit#(n) decoded_subcodeword_in, Bit#(n) msg_ind); 
	method ActionValue#(MSG_MSG_CNT#(n,m)) getCollectedBits();
endinterface

module mkBitCollector(BitCollectorIfc#(n,m)) provisos (Log#(TAdd#(1, n), m), Add#(TLog#(n), 1, m));
	SSerializerIfc#(n) serializer <- mkSSerializer;
	FIFO#(MSG_MSG_CNT#(n, m)) fifo_msg_msg_cnt_out <- mkPipelineFIFO;
	FIFO#(UInt#(m)) fifo_bit_cnt <- mkPipelineFIFO;	
	Reg#(Bit#(n)) reg_bit_collected <- mkReg(0);
	Reg#(UInt#(m)) reg_bit_cnt <- mkReg(0);

	rule serializer_to_out (reg_bit_cnt < fifo_bit_cnt.first);
		bit current_bit <- serializer.getBit();
		reg_bit_collected[reg_bit_cnt] <= current_bit;
		reg_bit_cnt <= reg_bit_cnt + 1;
	endrule

        rule serializer_to_out_done (reg_bit_cnt == fifo_bit_cnt.first);
                //$display("Bit Collector: %b, [%d]", reg_bit_collected, fifo_bit_cnt.first);
                MSG_MSG_CNT#(n, m) msg_msg_cnt;
                msg_msg_cnt.msg_vec = reg_bit_collected;
                msg_msg_cnt.msg_cnt = fifo_bit_cnt.first;
                fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
                fifo_bit_cnt.deq();
                reg_bit_cnt <= 0;
        endrule

		
        method Action putDecVec(Bit#(n) decoded_subcodeword_in, Bit#(n) msg_ind);
		let countOneVal = countOnes(msg_ind);
		if (countOneVal == fromInteger(valueOf(n))) begin
			MSG_MSG_CNT#(n, m) msg_msg_cnt;
			msg_msg_cnt.msg_vec = decoded_subcodeword_in;
			msg_msg_cnt.msg_cnt = countOneVal;
			fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
		end
		else if (countOneVal > 0) begin
			serializer.putVector(decoded_subcodeword_in, msg_ind);
			fifo_bit_cnt.enq(countOneVal);
		end
		else if (countOneVal == 0) begin
                        MSG_MSG_CNT#(n, m) msg_msg_cnt;
                        msg_msg_cnt.msg_vec = 0;
                        msg_msg_cnt.msg_cnt = 0;
                        fifo_msg_msg_cnt_out.enq(msg_msg_cnt);	
		end	
	endmethod

        method ActionValue#(MSG_MSG_CNT#(n, m)) getCollectedBits();
		fifo_msg_msg_cnt_out.deq();
		return fifo_msg_msg_cnt_out.first;
	endmethod
endmodule


interface MergerIfc#(type n, type m);
	method Action putMsgVec(MSG_MSG_CNT#(n, m) msg_msg_cnt);
	method Action resetOffset();
	method ActionValue#(Bit#(n)) getMsg();
endinterface

module mkMerger(MergerIfc#(n, m)) provisos (Log#(TAdd#(1, n), m));
	FIFO#(MSG_MSG_CNT#(n, m)) fifo_msg_msg_cnt_in <- mkPipelineFIFO;
	FIFO#(Bit#(n)) fifo_msg_out <- mkPipelineFIFO;
	Reg#(Bit#(n)) reg_collected_bits <- mkReg(0);
	Reg#(UInt#(m)) reg_offset <- mkReg(0);
	
        rule combine_msg_bits_main;
                let msg_msg_cnt_in = fifo_msg_msg_cnt_in.first; fifo_msg_msg_cnt_in.deq();
		let end_idx = reg_offset + msg_msg_cnt_in.msg_cnt;
                Bit#(n) msg_vec = msg_msg_cnt_in.msg_vec;
                Bit#(n) mask = '1 << reg_offset;
                let current_collected_bits = reg_collected_bits;
                current_collected_bits = (current_collected_bits & (~mask) ) | ((msg_vec << reg_offset) & mask);
		//$display("Merger: %b, [%d], offset %d", msg_msg_cnt_in.msg_vec, msg_msg_cnt_in.msg_cnt, reg_offset);
		if (end_idx > fromInteger(valueOf(n)-1)) begin
			let prev_len = fromInteger(valueOf(n)) - reg_offset;
			Bit#(n) msg_vec_remainder = msg_vec >> prev_len;
			fifo_msg_out.enq(current_collected_bits);
                        reg_collected_bits <= msg_vec_remainder;
			reg_offset <= end_idx - fromInteger(valueOf(n));
		end
		else begin
			reg_collected_bits <= current_collected_bits;
			reg_offset <= end_idx;	
		end	
	endrule

	method Action putMsgVec(MSG_MSG_CNT#(n, m) msg_msg_cnt);
		//$display("Merger: %b, [%d]", msg_msg_cnt.msg_vec, msg_msg_cnt.msg_cnt);
		if (msg_msg_cnt.msg_cnt > 0)
			fifo_msg_msg_cnt_in.enq(msg_msg_cnt);
	endmethod

	method Action resetOffset();
		reg_offset <= 0;
	endmethod

        method ActionValue#(Bit#(n)) getMsg();
		fifo_msg_out.deq();
		return fifo_msg_out.first;
	endmethod
endmodule

interface CombinerIfc#(type in_size, type out_size);
        method Action put(Bit#(in_size) data_in, Bool is_last);
        method Action resetOffset();
        method ActionValue#(Bit#(out_size)) getCombined();
endinterface

module mkCombiner(CombinerIfc#(in_size, out_size)) provisos (Add#(unused, in_size, out_size));
        FIFO#(Bit#(in_size)) fifo_data_in <- mkPipelineFIFO;
        FIFO#(Bool) fifo_is_last <- mkPipelineFIFO;
        FIFO#(Bit#(out_size)) fifo_combined_data_out <- mkPipelineFIFO;
        Reg#(Bit#(out_size)) reg_combined_data <- mkReg(0);
        Reg#(UInt#(9)) reg_offset <- mkReg(0);

        rule combine_data_in_main;
                let data_in = fifo_data_in.first; fifo_data_in.deq();
                let is_last = fifo_is_last.first; fifo_is_last.deq();
                let end_idx = reg_offset + fromInteger(valueOf(in_size));
                Bit#(out_size) mask = '1;
                mask = mask << reg_offset;
                let current_combined_data = reg_combined_data;
                current_combined_data = (current_combined_data & (~mask) ) | ((zeroExtend(data_in) << reg_offset) & mask);
                //$display("Merger: %b, [%d], offset %d", msg_msg_cnt_in.msg_vec, msg_msg_cnt_in.msg_cnt, reg_offset);
                if (end_idx >= fromInteger(valueOf(out_size))) begin
                        let prev_len = fromInteger(valueOf(out_size)) - reg_offset;
                        Bit#(out_size) data_in_remainder = zeroExtend(data_in >> prev_len);
                        fifo_combined_data_out.enq(current_combined_data);
                        reg_combined_data <= data_in_remainder;
                        reg_offset <= end_idx - fromInteger(valueOf(out_size));
                end
                else begin
                        if (!is_last) begin
                                reg_combined_data <= current_combined_data;
                                reg_offset <= end_idx;
                        end
                        else begin
                                fifo_combined_data_out.enq(current_combined_data);
                                reg_combined_data <= 0;
                                reg_offset <= 0;
                        end
                end
        endrule

        method Action put(Bit#(in_size) data_in, Bool is_last);
                fifo_data_in.enq(data_in);
                fifo_is_last.enq(is_last);
        endmethod

        method Action resetOffset();
                reg_offset <= 0;
        endmethod

        method ActionValue#(Bit#(out_size)) getCombined();
                fifo_combined_data_out.deq();
                return fifo_combined_data_out.first;
        endmethod
endmodule

interface SplitterIfc#(type in_size, type out_size);
        method Action put(Bit#(in_size) data_in);
        method Action resetOffset();
        method ActionValue#(Bit#(out_size)) getSplit();
endinterface: SplitterIfc

module mkSplitter(SplitterIfc#(in_size, out_size)) provisos (Add#(unused, out_size, in_size));
        FIFO#(Bit#(in_size)) fifo_data_in <- mkBypassFIFO;
        FIFO#(Bit#(out_size)) fifo_split_data_out <- mkPipelineFIFO;
        FIFO#(Bit#(in_size)) fifo_data_in_remaining <- mkPipelineFIFO;
        Reg#(UInt#(9)) offset <- mkReg(0);

        rule split_data_in_main;// (!remaining);
                        let end_position = offset + fromInteger(valueOf(out_size));
                        if (end_position > fromInteger(valueOf(in_size))) begin
                                        fifo_data_in_remaining.enq((fifo_data_in.first >> offset));
                                        fifo_data_in.deq();
                                end
                        else begin
                                        Bit#(out_size) data_out = truncate(fifo_data_in.first >> offset);
                                        fifo_split_data_out.enq(data_out);
                                        if (end_position == fromInteger(valueOf(in_size))) begin
                                                        fifo_data_in.deq();
                                                        offset <= 0;
                                                end
                                        else
                                                offset <= end_position;
                                end
                        //$display("First stage, offset = %d", offset);
        endrule

        rule split_data_in_remain;// (remaining);
                let data_in_remaining = fifo_data_in_remaining.first;
                Bit#(out_size) split_data_out;
                let prev_len = fromInteger(valueOf(in_size)) - offset;
                Bit#(in_size) data_in_new = fifo_data_in.first << prev_len;
                Bit#(in_size) mask = '1;
                mask = mask << prev_len;
                split_data_out = truncate((data_in_remaining & (~mask)) | (data_in_new & mask));
                fifo_split_data_out.enq(split_data_out);
                fifo_data_in_remaining.deq();

                let end_position = offset + fromInteger(valueOf(out_size));
                offset <= end_position - fromInteger(valueOf(in_size));

        endrule

        method Action put(Bit#(in_size) data_in);
                fifo_data_in.enq(data_in);
        endmethod

        method Action resetOffset();
                offset <= 0;
        endmethod

        method ActionValue#(Bit#(out_size)) getSplit();
                fifo_split_data_out.deq();
                return fifo_split_data_out.first;
        endmethod

endmodule: mkSplitter

(* synthesize, options = "-no-aggressive-conditions" *)
module mkBitCollector32(BitCollectorIfc#(32, 6));
        let ifc();
        mkBitCollector _temp(ifc);
        return (ifc);
endmodule

(* synthesize, options = "-no-aggressive-conditions" *)
module mkMerger32(MergerIfc#(32, 6));
        let ifc();
        mkMerger _temp(ifc);
        return (ifc);
endmodule


interface DemapperIfc;
	method Action setPageNum(PAGE_NUM page_num);
	//method PAGE_NUM getPageNum();
        method Action putDecVec(Codeword decoded_subcodeword_in);
        method ActionValue#(MESSAGE) getDemappedOut();
endinterface

(* synthesize, options = "-no-aggressive-conditions" *)
module mkDemapper(DemapperIfc);	
	Vector#(N_PAR_BIT_COLLECTOR, BitCollectorIfc#(32,6)) vector_bit_collector <- replicateM(mkBitCollector32);
	Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(Bit#(32))) vector_fifo_bit_collector_in <- replicateM(mkGLFIFOF(True, False));
	Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(Bit#(32))) vector_fifo_msg_ind_in <- replicateM(mkGLFIFOF(True, False));
        Vector#(N_PAR_BIT_COLLECTOR, FIFOF#(MSG_MSG_CNT#(32,6))) vector_fifo_bit_collector_out <- replicateM(mkGLFIFOF(False, True));
	
	MergerIfc#(32, 6) merger <- mkMerger32;
	FIFO#(Codeword) fifo_subcodeword_in <- mkPipelineFIFO;

	FIFO#(PAGE_NUM) fifo_page_num <- mkFIFO1;
	Reg#(UInt#(7)) reg_msg_ind_counter <- mkReg(0);
	
	Reg#(UInt#(SIZE_N_PAR_BIT_COLLECTOR)) reg_in_fifo_cnt <- mkReg(0);
        Reg#(UInt#(SIZE_N_PAR_BIT_COLLECTOR)) reg_out_fifo_cnt <- mkReg(0);

	FIFO#(MESSAGE) fifo_demapped_out <- mkPipelineFIFO;

        SplitterIfc#(256, 32) splitter_msg_vec <- mkSplitter;
        SplitterIfc#(256, 32) splitter_msg_ind <- mkSplitter;
        CombinerIfc#(32, 256) combiner <- mkCombiner;

	rule splitting_msg_ind;
                splitter_msg_ind.put(get_msg_bit_ind(truncate(reg_msg_ind_counter), fifo_page_num.first));
		if (reg_msg_ind_counter < 63)
                	reg_msg_ind_counter <= reg_msg_ind_counter + 1;		
		else begin	
			reg_msg_ind_counter <= 0;
			fifo_page_num.deq();
		end
	endrule

        rule input_fifo_to_multiple_fifos (vector_fifo_bit_collector_in[reg_in_fifo_cnt].notFull);
		let subcodeword_in <- splitter_msg_vec.getSplit();//fifo_subcodeword_in.first; fifo_subcodeword_in.deq();
		let msg_ind <- splitter_msg_ind.getSplit();

		vector_fifo_bit_collector_in[reg_in_fifo_cnt].enq(subcodeword_in);
		vector_fifo_msg_ind_in[reg_in_fifo_cnt].enq(msg_ind);

		if (reg_in_fifo_cnt < fromInteger(valueOf(N_PAR_BIT_COLLECTOR)-1))
			reg_in_fifo_cnt <= reg_in_fifo_cnt + 1;
		else
			reg_in_fifo_cnt <= 0;
	endrule

        for (Integer i=0 ; i<valueOf(N_PAR_BIT_COLLECTOR) ; i=i+1)
        rule fifo_to_bit_collector (vector_fifo_bit_collector_in[i].notEmpty && vector_fifo_msg_ind_in[i].notEmpty);
               	vector_bit_collector[i].putDecVec(vector_fifo_bit_collector_in[i].first, vector_fifo_msg_ind_in[i].first);
               	vector_fifo_bit_collector_in[i].deq();
		vector_fifo_msg_ind_in[i].deq();
	endrule
	
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

	rule merger_to_combiner;
		let merger_out <- merger.getMsg();
		combiner.put(merger_out, False);
	endrule

        method Action setPageNum(PAGE_NUM page_num);
		fifo_page_num.enq(page_num);
	endmethod

        method Action putDecVec(Codeword subcodeword_in);
		//fifo_subcodeword_in.enq(subcodeword_in);
		splitter_msg_vec.put(subcodeword_in);	
	endmethod

        method ActionValue#(MESSAGE) getDemappedOut();
		let demapped_out <- combiner.getCombined();
		return demapped_out;
	endmethod
endmodule

endpackage: Demapper 
