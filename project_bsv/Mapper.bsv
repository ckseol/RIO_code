package Mapper;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
//import RIO_subencoder_1st::*;

import Polar_codec_common_revised::*;
//`include "polar_codec_common.bsv"
//`include "encoder_config.bsv"

typedef 32 N_PAR_BIT_PLACER;
typedef 5 SIZE_N_PAR_BIT_PLACER;

typedef struct {Bit#(n) msg_vec; UInt#(m) msg_cnt;} MSG_MSG_CNT#(numeric type n, numeric type m) deriving(Bits, Eq);
typedef struct {Bit#(n) msg_vec; UInt#(m) msg_cnt; Bit#(n) msg_ind;} TAKE_PARTIAL_OUT#(numeric type n, numeric type m) deriving(Bits, Eq);

interface SerializerIfc#(type n, type m);
	method Action putVector(MSG_MSG_CNT#(n,m) msg_msg_cnt);
	method ActionValue#(bit) getBit();
endinterface: SerializerIfc

//(* synthesize, options = "-no-aggressive-conditions" *)
module mkSerializer(SerializerIfc#(n, m)) provisos (Log#(TAdd#(1, n), m));
	FIFO#(MSG_MSG_CNT#(n,m)) fifo_msg_msg_cnt_in <- mkPipelineFIFO;
	FIFO#(bit) fifo_bit_out <- mkPipelineFIFO;
	Reg#(UInt#(m)) bit_count <- mkReg(0);

	rule serialize;
		let msg_msg_cnt_in = fifo_msg_msg_cnt_in.first;
		if (bit_count < msg_msg_cnt_in.msg_cnt)
                        fifo_bit_out.enq(msg_msg_cnt_in.msg_vec[bit_count]);
		if (bit_count == msg_msg_cnt_in.msg_cnt) begin
			fifo_msg_msg_cnt_in.deq();
			bit_count <= 0;
		end
		else begin
			bit_count <= bit_count + 1;
		end
	endrule

        method Action putVector(MSG_MSG_CNT#(n, m) msg_msg_cnt);
		fifo_msg_msg_cnt_in.enq(msg_msg_cnt);
	endmethod
		
        method ActionValue#(bit) getBit();
		let bit_out = fifo_bit_out.first;
		fifo_bit_out.deq();
		return bit_out;
	endmethod

endmodule: mkSerializer



interface TakePartialIfc#(type n, type m);
	method Action putMsgInd(Bit#(n) msg_ind);
	method Action putMsgVec(Bit#(n) msg_vec);
	method Action resetOffset();
	method ActionValue#(TAKE_PARTIAL_OUT#(n,m)) getMsg();
endinterface: TakePartialIfc

//(* synthesize, options = "-no-aggressive-conditions" *)
module mkTakePartial(TakePartialIfc#(n, m)) provisos (Log#(TAdd#(1, n), m), Add#(TLog#(n), 1, m));
	FIFO#(Bit#(n)) fifo_msg_in <- mkBypassFIFO;
	FIFO#(UInt#(m)) fifo_bit_cnt <- mkBypassFIFO;
	FIFO#(Bit#(n)) fifo_msg_ind <- mkBypassFIFO;
	//FIFO#(PAGE_NUM) fifo_page_num <- mkBypassFIFO;
	FIFO#(TAKE_PARTIAL_OUT#(n,m)) fifo_msg_msg_cnt_out <- mkPipelineFIFO;
	FIFO#(MSG_MSG_CNT#(n,m)) fifo_msg_msg_cnt_remaining <- mkPipelineFIFO;
	Reg#(UInt#(m)) offset <- mkReg(0);
	Reg#(Bool) remaining <- mkReg(False);

	rule take_partial_msg_main (fifo_bit_cnt.first > 0);// (!remaining);
			let out_msg_bit_cnt = fifo_bit_cnt.first;
			let end_position = offset + out_msg_bit_cnt;	
			if (end_position > fromInteger(valueOf(n))) begin
					MSG_MSG_CNT#(n,m) msg_msg_cnt;
                        	        msg_msg_cnt.msg_vec = fifo_msg_in.first >> offset;
                        	        msg_msg_cnt.msg_cnt = out_msg_bit_cnt;
					fifo_msg_msg_cnt_remaining.enq(msg_msg_cnt);			
					//offset <= end_position - fromInteger(valueOf(MSG_BIT_WIDTH));
					fifo_msg_in.deq();
					//remaining <= True;
				end
			else begin
					TAKE_PARTIAL_OUT#(n,m) msg_msg_cnt;
					msg_msg_cnt.msg_vec = fifo_msg_in.first >> offset;
					msg_msg_cnt.msg_cnt = out_msg_bit_cnt;
					msg_msg_cnt.msg_ind = fifo_msg_ind.first;
					fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
					fifo_bit_cnt.deq();
					fifo_msg_ind.deq();
					if (end_position == fromInteger(valueOf(n))) begin
							fifo_msg_in.deq();
							offset <= 0;
						end
					else
						offset <= end_position;
				end
			//$display("First stage, offset = %d", offset);
	endrule

	rule take_partial_msg_no_input (fifo_bit_cnt.first == 0);
	                fifo_bit_cnt.deq();
			fifo_msg_ind.deq();
                        TAKE_PARTIAL_OUT#(n,m) msg_msg_cnt;
                        msg_msg_cnt.msg_vec = 0;
                        msg_msg_cnt.msg_cnt = 0;
			msg_msg_cnt.msg_ind = fifo_msg_ind.first;
                        fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
	endrule 
	
        rule take_partial_msg_remain (fifo_bit_cnt.first > 0);// (remaining);
                let msg_msg_cnt_remaining = fifo_msg_msg_cnt_remaining.first;
		TAKE_PARTIAL_OUT#(n,m) msg_msg_cnt;
		let prev_len = fromInteger(valueOf(n)) - offset;
                Bit#(n) msg_remaining = fifo_msg_in.first << prev_len;
		Bit#(n) mask_vec = ('1 << prev_len); 
		msg_msg_cnt.msg_vec = (msg_msg_cnt_remaining.msg_vec & (~mask_vec)) | (msg_remaining & mask_vec);
		msg_msg_cnt.msg_cnt = msg_msg_cnt_remaining.msg_cnt;
		msg_msg_cnt.msg_ind = fifo_msg_ind.first;
		fifo_msg_msg_cnt_out.enq(msg_msg_cnt);
		fifo_bit_cnt.deq();
		fifo_msg_ind.deq();
		fifo_msg_msg_cnt_remaining.deq();
		//remaining <= False;

		let end_position = offset + msg_msg_cnt.msg_cnt;
		offset <= end_position - fromInteger(valueOf(n));
	
        endrule
	

        method Action putMsgInd(Bit#(n) msg_ind); //MSG_IND_IDX msg_ind_idx, PAGE_NUM page_num);
		//let msg_ind = get_msg_bit_ind(msg_ind_idx, page_num);
		fifo_bit_cnt.enq(countOnes(msg_ind));
		fifo_msg_ind.enq(msg_ind);
		//fifo_page_num.enq(page_num);
		//$display("Put message in: %d", countOnes(msg_ind));
	endmethod

        method Action putMsgVec(Bit#(n) msg_in);
		fifo_msg_in.enq(msg_in);
	endmethod

	method Action resetOffset();
		offset <= 0;
	endmethod

        //method ActionValue#(MSG_MSG_CNT) getMsg();
        method ActionValue#(TAKE_PARTIAL_OUT#(n, m)) getMsg();
		fifo_msg_msg_cnt_out.deq();
		return fifo_msg_msg_cnt_out.first;
	endmethod

endmodule: mkTakePartial


interface BitPlacerIfc#(type n, type m);
        method Action putMsgVecInd(TAKE_PARTIAL_OUT#(n, m) msg_in);
	method ActionValue#(Bit#(n)) getMappedOut(); 
endinterface: BitPlacerIfc

//(* synthesize, options = "-no-aggressive-conditions" *)
module mkBitPlacer(BitPlacerIfc#(n, m)) provisos (Log#(TAdd#(1, n), m), Log#(n, l), Add#(l, 1, m), Add#(TLog#(n), 1, m));
	FIFO#(Bit#(n)) fifo_msg_ind <- mkPipelineFIFO;
	FIFO#(UInt#(m)) fifo_bit_cnt <- mkPipelineFIFO;
	FIFO#(UInt#(l)) fifo_1_end_ind <- mkPipelineFIFO;
	FIFO#(MSG_MSG_CNT#(n, m)) fifo_msg_msg_cnt_in <- mkPipelineFIFO;
	Reg#(Bit#(n)) mapped_out_vector <-mkReg(0);
	Reg#(UInt#(m)) bit_count <- mkReg(0);
	FIFO#(Bit#(n)) fifo_mapped_out <- mkPipelineFIFO;

	SerializerIfc#(n, m) serializer <- mkSerializer;

	rule mapping_all_input (fifo_bit_cnt.first == fromInteger(valueOf(n)));
		let msg_msg_cnt = fifo_msg_msg_cnt_in.first; fifo_msg_msg_cnt_in.deq();
		fifo_mapped_out.enq(msg_msg_cnt.msg_vec);
		fifo_msg_ind.deq();
		fifo_bit_cnt.deq();
		fifo_1_end_ind.deq();
	endrule   	

	rule serialization (fifo_bit_cnt.first > 0 && fifo_bit_cnt.first < fromInteger(valueOf(n)));
		serializer.putVector(fifo_msg_msg_cnt_in.first); //fifo_msg_msg_cnt_in.deq();
	endrule

	rule mapping_input (fifo_bit_cnt.first > 0 && fifo_bit_cnt.first < fromInteger(valueOf(n)));
		let msg_ind = fifo_msg_ind.first;
		let tmp = mapped_out_vector;
		if (msg_ind[bit_count] == 0)
			tmp[bit_count] = 0;
		else 
			tmp[bit_count] <- serializer.getBit();
		
		mapped_out_vector <= tmp;
		if (bit_count == zeroExtend(fifo_1_end_ind.first)) begin
			fifo_mapped_out.enq(tmp);
			fifo_msg_ind.deq();
			fifo_bit_cnt.deq();
			fifo_1_end_ind.deq();
			fifo_msg_msg_cnt_in.deq();
		end
		else 
			bit_count <= bit_count + 1;
	endrule

        rule mapping_no_input (fifo_bit_cnt.first == 0);
                fifo_mapped_out.enq(0);
                fifo_msg_ind.deq();
                fifo_bit_cnt.deq();
		//fifo_msg_msg_cnt_in.deq();
        endrule

        //method Action putMsgVecInd(MSG_MSG_CNT msg_msg_cnt_in, Codeword msg_ind);
        method Action putMsgVecInd(TAKE_PARTIAL_OUT#(n, m) take_partial_out);
		MSG_MSG_CNT#(n, m) msg_msg_cnt_in;
		msg_msg_cnt_in.msg_vec = take_partial_out.msg_vec;
                msg_msg_cnt_in.msg_cnt = take_partial_out.msg_cnt;

		let msg_ind = take_partial_out.msg_ind;
	
                Vector#(n, bit) msg_ind_vec;
                for (Integer i=0 ; i<valueOf(n) ; i=i+1)
                        msg_ind_vec[i] = msg_ind[i];
                UInt#(m) countOneVal = countOnes(msg_ind);
                fifo_msg_ind.enq(take_partial_out.msg_ind);
                fifo_bit_cnt.enq(countOneVal);
		if (countOneVal > 0) begin
                	Maybe#(UInt#(l)) start_idx = findElem(1'b1, msg_ind_vec);
                	Maybe#(UInt#(l)) end_idx = findElem(1'b1, reverse(msg_ind_vec));
                	mapped_out_vector <= 0;
	                if (isValid(start_idx))
        	                bit_count <= zeroExtend(fromMaybe(?, start_idx));           
        	        else
                	        bit_count <= 0;
                
                	if (isValid(end_idx))
                        	fifo_1_end_ind.enq(fromInteger(valueOf(n)-1)-fromMaybe(?, end_idx)); 
                	//$display("%d, %d, %d", countOnes(msg_ind), fromMaybe(?, start_idx), fromInteger(valueOf(Codeword_len)-1)-fromMaybe(?, end_idx));
			//fifo_msg_msg_cnt_in.enq(msg_msg_cnt_in);
			fifo_msg_msg_cnt_in.enq(msg_msg_cnt_in);
		end
        endmethod

        method ActionValue#(Bit#(n)) getMappedOut();
		let out = fifo_mapped_out.first; fifo_mapped_out.deq();
		//$display("[Bit placer] %b", out);
		return out;
	endmethod

endmodule: mkBitPlacer

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
module mkSerializer32(SerializerIfc#(32, 6));
        let ifc();
        mkSerializer _temp(ifc);
        return (ifc);
endmodule

(* synthesize, options = "-no-aggressive-conditions" *)
module mkTakePartial32(TakePartialIfc#(32, 6));
        let ifc();
        mkTakePartial _temp(ifc);
        return (ifc);
endmodule

(* synthesize, options = "-no-aggressive-conditions" *)
module mkBitPlacer32(BitPlacerIfc#(32, 6));
        let ifc();
        mkBitPlacer _temp(ifc);
        return (ifc);
endmodule


interface MapperIfc;
	method Action setPageNum(PAGE_NUM page_num);
        method Action putMsgVec(MESSAGE msg_in);
        method ActionValue#(Codeword) getMappedOut();
endinterface

(* synthesize, options = "-no-aggressive-conditions" *)
module mkMapper(MapperIfc);
	FIFO#(MESSAGE) fifo_msg_in <- mkFIFO1;

 	FIFO#(Codeword) fifo_mapper_out <- mkLFIFO;


	FIFO#(PAGE_NUM) fifo_page_num <- mkFIFO1;
	
        SplitterIfc#(256, 32) splitter_msg_vec <- mkSplitter;
	SplitterIfc#(256, 32) splitter_msg_ind <- mkSplitter;
        CombinerIfc#(32, 256) combiner <- mkCombiner;
	

	TakePartialIfc#(32, 6) take_partial <- mkTakePartial32;
	
	Vector#(N_PAR_BIT_PLACER, BitPlacerIfc#(32, 6)) vec_bit_placer <- replicateM(mkBitPlacer32);
	Vector#(N_PAR_BIT_PLACER, FIFOF#(TAKE_PARTIAL_OUT#(32, 6))) vec_take_partial_out <- replicateM(mkGLFIFOF(True, False));
        Vector#(N_PAR_BIT_PLACER, FIFOF#(Bit#(32))) vec_fifo_bit_placer_out <- replicateM(mkGLFIFOF(False, True));

	Reg#(Bit#(SIZE_N_PAR_BIT_PLACER)) reg_bit_placer_idx <- mkReg(0);
	Reg#(Bit#(SIZE_N_PAR_BIT_PLACER)) reg_mapper_out_idx <- mkReg(0);	

        //BitPlacerIfc bit_placer <- mkBitPlacer;


        Reg#(UInt#(9)) msg_ind_counter <- mkReg(0);
	Reg#(UInt#(9)) reg_mapper_out_counter <- mkReg(0);
	//Reg#(Bool) reg_deq_fifo_page_num <- mkReg(False);

	//rule take_partial_put_msg_ind (msg_ind_counter < 9'd256);
	rule msg_ind_to_splitter (msg_ind_counter <= zeroExtend(get_eom_bit_idx(fifo_page_num.first)));
		splitter_msg_ind.put(get_msg_bit_ind(truncate(msg_ind_counter), fifo_page_num.first));
		if (msg_ind_counter ==  zeroExtend(get_eom_bit_idx(fifo_page_num.first))) begin
			msg_ind_counter <= 0;
			fifo_page_num.deq();
		end 
		else 
			msg_ind_counter <= msg_ind_counter + 1;
                //$display("Page[%d][%d]", fifo_page_num.first, msg_ind_counter);
	endrule

        rule take_partial_put_msg_ind;// (msg_ind_counter <= zeroExtend(get_eom_bit_idx(fifo_page_num.first)));
		//take_partial.putMsgInd(get_msg_bit_ind(truncate(msg_ind_counter), fifo_page_num.first));

		let msg_bit_ind <- splitter_msg_ind.getSplit();
		take_partial.putMsgInd(msg_bit_ind);
		//msg_ind_counter <= msg_ind_counter + 1;
		//$display("[%d]", msg_ind_counter);
	endrule

	rule take_partial_put_msg_vec;
                let msg_bit_vec <- splitter_msg_vec.getSplit();
                take_partial.putMsgVec(msg_bit_vec);
	endrule

	rule take_partial_to_fifos;
		if (vec_take_partial_out[reg_bit_placer_idx].notFull) begin
			let msg_msg_cnt <- take_partial.getMsg();
			vec_take_partial_out[reg_bit_placer_idx].enq(msg_msg_cnt);
			if (reg_bit_placer_idx < fromInteger(valueOf(N_PAR_BIT_PLACER)-1))
				reg_bit_placer_idx <= reg_bit_placer_idx + 1;
			else
				reg_bit_placer_idx <= 0;
		end
	endrule

	for (Integer i=0 ; i<valueOf(N_PAR_BIT_PLACER) ; i=i+1)
	rule fifos_to_bit_placers;
		vec_bit_placer[i].putMsgVecInd(vec_take_partial_out[i].first);
		vec_take_partial_out[i].deq();
	endrule

        for (Integer i=0 ; i<valueOf(N_PAR_BIT_PLACER) ; i=i+1)
	rule bit_placers_to_fifos;
		if (vec_fifo_bit_placer_out[i].notFull) begin
			let bit_placer_out <- vec_bit_placer[i].getMappedOut();
			vec_fifo_bit_placer_out[i].enq(bit_placer_out);
		end
	endrule

	rule multiple_fifos_to_fifo_mapper_out;// (!reg_deq_fifo_page_num);
		if (vec_fifo_bit_placer_out[reg_mapper_out_idx].notEmpty) begin
			//fifo_mapper_out.enq(vec_fifo_bit_placer_out[reg_mapper_out_idx].first);
			combiner.put(vec_fifo_bit_placer_out[reg_mapper_out_idx].first, False);			
			if (reg_mapper_out_counter < 511)//zeroExtend(get_eom_bit_idx(fifo_page_num.first)))
				reg_mapper_out_counter <= reg_mapper_out_counter + 1;
			else begin
				reg_mapper_out_counter <= 0;
				//fifo_page_num.deq();
				//msg_ind_counter <= 0;
				//reg_deq_fifo_page_num <= True;
			end
			vec_fifo_bit_placer_out[reg_mapper_out_idx].deq();
                        if (reg_mapper_out_idx < fromInteger(valueOf(N_PAR_BIT_PLACER)-1))
                                reg_mapper_out_idx <= reg_mapper_out_idx + 1;
                        else
                                reg_mapper_out_idx <= 0;			
		end
	endrule

	method Action setPageNum(PAGE_NUM page_num);
		//reg_page_num <= page_num;
		fifo_page_num.enq(page_num);
	endmethod

        method Action putMsgVec(MESSAGE msg_in);
		//take_partial.putMsgVec(msg_in);
		splitter_msg_vec.put(msg_in);
        endmethod

        method ActionValue#(Codeword) getMappedOut();
		//let bit_placer_output = fifo_mapper_out.first;
		//fifo_mapper_out.deq();
		//return fifo_mapper_out.first;
		let mapper_out_combined <- combiner.getCombined();
		return mapper_out_combined;
        endmethod	
endmodule

endpackage: Mapper 
