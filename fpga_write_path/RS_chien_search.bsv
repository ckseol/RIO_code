package RS_chien_search;
import Vector::*;
import FIFO::*;
import SpecialFIFOs::*;
import RS_common::*;

interface RSChienSearchIfc;
        method Action load_err_loc_poly(POLYNOMIAL err_loc_poly, UInt#(3) mu);
        method ActionValue#(UInt#(6)) get_loc_j();
	method Maybe#(Bool) get_uncorr_flag();
endinterface: RSChienSearchIfc


(* synthesize, options = "-no-aggressive-conditions" *)
module mkRSChienSearch(RSChienSearchIfc);
	FIFO#(POLYNOMIAL) fifo_err_loc_poly_in <- mkFIFO1;
	FIFO#(UInt#(3)) fifo_mu <- mkFIFO1;
	FIFO#(UInt#(6)) fifo_loc_j_out <- mkPipelineFIFO;
	//Reg#(Bool) reg_uncorr_flag <- mkReg(False);
	Reg#(Maybe#(Bool)) reg_uncorr_flag <- mkRegU;
	Reg#(UInt#(7)) reg_i <- mkReg(0);
	Reg#(UInt#(3)) reg_loc_cnt <- mkReg(0);
	
	Vector#(DOUBLE_T_RS, Reg#(SYMBOL)) vec_reg_alpha_list <- replicateM(mkReg(1));

	rule initialize (reg_i == 0);
		for (Integer i=0 ; i<valueOf(DOUBLE_T_RS) ; i=i+1)
			vec_reg_alpha_list[i] <= 1;
		reg_i <= 1;
		reg_loc_cnt <= 0;
		reg_uncorr_flag <= tagged Invalid;
	endrule

	rule err_loc_vec (reg_i > 0 && reg_i <= fromInteger(valueOf(CODEWORD_LEN)));
		Vector#(DOUBLE_T_RS, SYMBOL) alpha_nk;
		alpha_nk[0] = 6'd33;
                alpha_nk[1] = 6'd49;
                alpha_nk[2] = 6'd57;
                alpha_nk[3] = 6'd61;
                alpha_nk[4] = 6'd63;
                alpha_nk[5] = 6'd62;
                alpha_nk[6] = 6'd31;
                alpha_nk[7] = 6'd46;
                alpha_nk[8] = 6'd23;
                alpha_nk[9] = 6'd42;
                alpha_nk[10] = 6'd21;
                alpha_nk[11] = 6'd43;
                alpha_nk[12] = 6'd52;
                alpha_nk[13] = 6'd26;
                alpha_nk[14] = 6'd13;
                alpha_nk[15] = 6'd39;
                alpha_nk[16] = 6'd50;
                alpha_nk[17] = 6'd25;
		
		
		POLYNOMIAL err_loc_poly = fifo_err_loc_poly_in.first;
		SYMBOL sum = err_loc_poly[0];
		let loc_cnt = reg_loc_cnt;
                for (Integer i=0 ; i<valueOf(DOUBLE_T_RS) ; i=i+1) begin
			SYMBOL tmp = vec_reg_alpha_list[i];
			sum = sum ^ gf_mul_m6(err_loc_poly[i+1], tmp); 
                        vec_reg_alpha_list[i] <= gf_mul_m6(vec_reg_alpha_list[i], alpha_nk[i]);
		end
		if (sum == 0) begin
			fifo_loc_j_out.enq(truncate(reg_i-1));
			reg_loc_cnt <= reg_loc_cnt + 1;
		end
		reg_i <= reg_i + 1;
	endrule	

	rule check_if_uncorr (reg_i > fromInteger(valueOf(CODEWORD_LEN)));
		fifo_err_loc_poly_in.deq();
                fifo_mu.deq();
                reg_uncorr_flag <= tagged Valid (reg_loc_cnt != fifo_mu.first);
                //fifo_uncorr_flag.enq(reg_loc_cnt != fifo_mu.first);
                reg_i <= 0;
	endrule

        method Action load_err_loc_poly(POLYNOMIAL err_loc_poly, UInt#(3) mu);
		fifo_err_loc_poly_in.enq(err_loc_poly);
		fifo_mu.enq(mu);
	endmethod

        method ActionValue#(UInt#(6)) get_loc_j();
		fifo_loc_j_out.deq();
		return fifo_loc_j_out.first;
	endmethod

	method Maybe#(Bool) get_uncorr_flag();
		return reg_uncorr_flag;
	endmethod

endmodule: mkRSChienSearch

interface RSForneyAlgorithmIfc;
        method Action load_input(POLYNOMIAL err_loc_poly, POLYNOMIAL err_eval_poly, UInt#(6) loc_j);
	method Action clear();
        method ActionValue#(SYMBOL) get_err_value();	
endinterface: RSForneyAlgorithmIfc

(* synthesize, options = "-no-aggressive-conditions" *)
module mkRSForneyAlgorithm(RSForneyAlgorithmIfc);
	
	FIFO#(SYMBOL) fifo_sum_omega <- mkPipelineFIFO;
	FIFO#(SYMBOL) fifo_sum_lambda_prime <- mkPipelineFIFO;
	FIFO#(SYMBOL) fifo_err_value_out <- mkPipelineFIFO;

	rule compute_err_value;
		let sum_omega = fifo_sum_omega.first;
		let sum_lambda_prime = fifo_sum_lambda_prime.first;
		fifo_sum_omega.deq();
		fifo_sum_lambda_prime.deq();

		SYMBOL err_value = gf_mul_m6(sum_omega, gf_inv(sum_lambda_prime));
		fifo_err_value_out.enq(err_value);
	endrule	

        method Action load_input(POLYNOMIAL err_loc_poly, POLYNOMIAL err_eval_poly, UInt#(6) loc_j);
		POLYNOMIAL err_loc_poly_prime = err_loc_poly;
		for (Integer i=0 ; i<valueOf(DOUBLE_T_RS)+1 ; i=i+2)
			err_loc_poly_prime[i] = 0;
		SYMBOL sum_omega = err_eval_poly[0];
		SYMBOL sum_lambda_prime = err_loc_poly_prime[0];
		let alpha_neg_loc_j_i = get_alpha_list(loc_j);
		for (Integer i=0 ; i<valueOf(DOUBLE_T_RS) ; i=i+1) begin
			sum_omega = sum_omega ^ gf_mul_m6(err_eval_poly[i+1], alpha_neg_loc_j_i[i]);
			sum_lambda_prime = sum_lambda_prime ^ gf_mul_m6(err_loc_poly_prime[i+1], alpha_neg_loc_j_i[i]);
		end	
		fifo_sum_omega.enq(sum_omega);
		fifo_sum_lambda_prime.enq(sum_lambda_prime);
		
	endmethod

	method Action clear();
		fifo_err_value_out.clear();
	endmethod

        method ActionValue#(SYMBOL) get_err_value();
		fifo_err_value_out.deq();
		return fifo_err_value_out.first;    
	endmethod

endmodule: mkRSForneyAlgorithm

endpackage: RS_chien_search

