package BlockInterleaver;

import Vector::*;

// Block interleaver
interface BlockInterleaverIfc#(type row_size, type col_size, type row_idx_size, type col_idx_size); 
	method Action reset_reg();
        method Action put_row(Bit#(row_size)  row_in, UInt#(row_idx_size) row_idx);
        method Bit#(row_size) get_row(UInt#(row_idx_size) row_idx);
        method Bit#(col_size) get_col(UInt#(col_idx_size) col_idx);
endinterface: BlockInterleaverIfc

//(* synthesize *)
module mkBlockInterleaver (BlockInterleaverIfc#(row_size, col_size, row_idx_size, col_idx_size)) 
				provisos (Log#(col_size, row_idx_size), Log#(row_size, col_idx_size));
/*
        Reg#(Vector#(col_size, Bit#(row_size))) reg_file <- mkReg(replicate(0));

        method Action put_row(Bit#(row_size) row_in, UInt#(row_idx_size) row_idx);
                reg_file[row_idx] <= row_in;
        endmethod
	
        method Bit#(row_size) get_row(UInt#(row_idx_size) row_idx);
		Bit#(row_size) row_data = reg_file[row_idx];
                return row_data;
        endmethod

        method Bit#(col_size) get_col(UInt#(col_idx_size) col_idx);
                Bit#(col_size) data_out = 0;
                for (Integer i=0 ; i<valueOf(col_size) ; i=i+1)
                       data_out[i] = reg_file[i][col_idx];
                return data_out;
        endmethod
*/
        Vector#(row_size, Reg#(Bit#(col_size))) reg_file <- replicateM(mkReg(0));
	
	method Action reset_reg();
		for (Integer i=0 ; i<valueOf(row_size) ; i=i+1)
			reg_file[i] <= 0;
	endmethod

        method Action put_row(Bit#(row_size) row_in, UInt#(row_idx_size) row_idx);
		for (Integer i=0 ; i<valueOf(row_size) ; i=i+1)
                	reg_file[i][row_idx] <= row_in[i];
        endmethod

        method Bit#(row_size) get_row(UInt#(row_idx_size) row_idx);
		Bit#(row_size) data_out = 0;
                for (Integer i=0 ; i<valueOf(row_size) ; i=i+1)
                        data_out[i] = reg_file[i][row_idx];
                return data_out; 
        endmethod

        method Bit#(col_size) get_col(UInt#(col_idx_size) col_idx);
		Bit#(col_size) data_out = reg_file[col_idx];
                return data_out;
        endmethod


endmodule: mkBlockInterleaver

endpackage: BlockInterleaver
