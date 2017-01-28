package RIO_code_scheme_common;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;

typedef Bit#(6) DATA_6BIT;
typedef Bit#(32) DATA_32BIT;
typedef UInt#(10) DATA_CNT; 
typedef 288 MAX_DATA_CNT;
typedef 5 MAX_PARITY_CNT;
typedef 63 RS_ENCODED_LEN;
typedef 45 RS_INFO_LEN;
typedef 32 RIO_CODE_2ND_DATA_LEN;
typedef 256 RIO_CODE_1ST_DATA_LEN;
typedef 261 BCH_ENCODED_DATA_LEN;
typedef 32 MAX_RIO_2ND_ENCODED_CNT;

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

endpackage: RIO_code_scheme_common
